# =============================================================================
# editor.s  --  Editor de texto estilo vim para el microcontrolador RISC-V
#               custom (RV32I), CE 3201, I Semestre 2026.
#
# VERSIÓN CORREGIDA — requiere el parche hw_patches/ aplicado al CPU.
# Con el parche, lui y auipc funcionan correctamente:
#   lui   rd, imm20   →  rd = imm20 << 12
#   auipc rd, imm20   →  rd = PC + (imm20 << 12)
# Por tanto, 'li' puede expandirse en lui+addi sin problema.
#
# Instrucciones usadas: lw sw addi andi ori xori slli srli sll srl add sub
#   and or xor slt slti beq bne blt bge jal jalr lui auipc
#   (ret = jalr x0,ra,0; j = jal x0,label; bnez/beqz = alias de beq/bne)
#
# Instrucciones PROHIBIDAS (no implementadas en este CPU):
#   mul div rem  lb lbu lh lhu  sb sh  bltu bgeu
#   instrucciones comprimidas, CSR, ecall, ebreak
#
# Estado del editor (registros caller-saved usados como globales persistentes):
#   s0 = cursor_col   (0-79)
#   s1 = cursor_row   (0-22)
#   s2 = modo         (0=INSERT, 1=COMMAND)
#   s3 = prefijo PS/2 (0=ninguno, 1=break 0xF0 recibido, 2=extended 0xE0)
#   s4 = flag ':' pendiente en modo COMMAND (0/1)
#   s5 = Shift activo (0=no, 1=sí; make 0x12/0x59, break F0 0x12/0x59)
#
# Atributos VGA:
#   Área de edición: fg=7 (gris claro), bg=0 (negro)  → 0x0700 | ascii
#   Barra de estado: fg=0 (negro), bg=7 (blanco)       → 0x7000 | ascii
# =============================================================================
# Nota de documentación:
#   Los comentarios agregados explican la intención de cada bloque y de las
#   instrucciones más importantes. No se cambió la lógica ni las direcciones
#   del firmware; el objetivo es que el archivo sea más fácil de defender.
# =============================================================================

# ---------------------------------------------------------------------------
# Mapa de periféricos (constantes globales)
# ---------------------------------------------------------------------------
.equ UART_CTRL,  0x00010040
.equ UART_TX,    0x00010044
.equ UART_RX,    0x00010048
.equ PS2_CTRL,   0x00010050
.equ PS2_RX,     0x00010054
.equ TIMER_CTRL, 0x00010060
.equ TIMER_DATA, 0x00010064
.equ VGA_CTRL,   0x00010120
.equ VGA_BUF,    0x00011000

.equ RAM_TOP,    0x00003000   # tope de RAM: sp inicial (crece hacia abajo)

.equ MODE_INSERT,  0
.equ MODE_COMMAND, 1

.equ COLS,       80
.equ ROWS,       23        # filas de edición 0-22; fila 23 = barra de estado
.equ EDIT_CELLS, 1840      # 80*23
.equ ALL_CELLS,  1920      # 80*24

.equ ATTR_NORMAL,  0x0700  # fg=7 bg=0
.equ ATTR_INVERSE, 0x7000  # fg=0 bg=7

# Scancodes PS/2 Set 2 (make codes)
.equ SC_ESC,       0x76
.equ SC_ENTER,     0x5A
.equ SC_BACKSPACE, 0x66
.equ SC_UP,        0x75    # llega con prefijo E0
.equ SC_DOWN,      0x72    # llega con prefijo E0
.equ SC_LEFT,      0x6B    # llega con prefijo E0
.equ SC_RIGHT,     0x74    # llega con prefijo E0
.equ SC_I,         0x43
.equ SC_COLON,     0x4C
.equ SC_SHIFT_L,   0x12
.equ SC_SHIFT_R,   0x59
.equ SC_W,         0x1D
.equ SC_R,         0x2D
.equ SC_Q,         0x15
.equ PREFIX_BREAK, 0xF0
.equ PREFIX_EXT,   0xE0

# ---------------------------------------------------------------------------
.section .text
.org 0x00000000
.global _start

# ===========================================================================
# _start — vector de reset
# ===========================================================================
_start:
    li   sp, RAM_TOP                  # carga RAM_TOP en sp para preparar una constante o dirección.

    li   s0, 0              # cursor_col
    li   s1, 0              # cursor_row
    li   s2, MODE_INSERT              # carga MODE_INSERT en s2 para preparar una constante o dirección.
    li   s3, 0              # prefijo PS/2
    li   s4, 0              # ':' pendiente
    li   s5, 0              # shift activo

    jal  ra, init_peripherals         # llama a init_peripherals y guarda la dirección de retorno en ra.
    jal  ra, clear_screen_full        # llama a clear_screen_full y guarda la dirección de retorno en ra.
    jal  ra, draw_status_bar          # llama a draw_status_bar y guarda la dirección de retorno en ra.
    jal  ra, update_cursor_hw         # llama a update_cursor_hw y guarda la dirección de retorno en ra.

# ===========================================================================
# main_loop — polling PS/2
# ===========================================================================
main_loop:
    li   t0, PS2_CTRL                 # carga PS2_CTRL en t0 para preparar una constante o dirección.
    lw   t1, 0(t0)                    # lee una palabra de 32 bits desde 0(t0) y la deja en t1.
    andi t1, t1, 1           # bit0 = rx_ready
    beq  t1, zero, main_loop          # salta a main_loop si t1 y zero son iguales.
    jal  ra, handle_ps2               # llama a handle_ps2 y guarda la dirección de retorno en ra.
    j    main_loop                    # salta directamente a main_loop sin guardar retorno.

# ===========================================================================
# init_peripherals
#   - Habilita teclado PS/2 (bit4 = kbd_enable)
#   - Arranca Timer en modo autoreload (referencia; el parpadeo del cursor
#     lo maneja el hardware VGA con VGA_CTRL[16]=1, sin intervención SW)
# ===========================================================================
init_peripherals:
    li   t0, PS2_CTRL                 # carga PS2_CTRL en t0 para preparar una constante o dirección.
    li   t1, 0x10            # bit4 = kbd_enable
    sw   t1, 0(t0)                    # guarda el valor de t1 en la dirección indicada por 0(t0).

    li   t0, TIMER_DATA               # carga TIMER_DATA en t0 para preparar una constante o dirección.
    li   t1, 25000000        # 0.5 s con prescaler 1000 (referencia)
    sw   t1, 0(t0)                    # guarda el valor de t1 en la dirección indicada por 0(t0).
    li   t0, TIMER_CTRL               # carga TIMER_CTRL en t0 para preparar una constante o dirección.
    li   t1, 0x09            # start + autoreload
    sw   t1, 0(t0)                    # guarda el valor de t1 en la dirección indicada por 0(t0).
    ret                               # retorna a la rutina que hizo la llamada.

# ===========================================================================
# clear_screen_full  — borra las 1920 celdas (edición + barra de estado)
# ===========================================================================
clear_screen_full:
    li   t0, VGA_BUF                  # carga VGA_BUF en t0 para preparar una constante o dirección.
    li   t1, ALL_CELLS                # carga ALL_CELLS en t1 para preparar una constante o dirección.
    li   t2, ATTR_NORMAL              # carga ATTR_NORMAL en t2 para preparar una constante o dirección.
    ori  t2, t2, 0x20        # espacio ' '
csf_loop:
    sw   t2, 0(t0)                    # guarda el valor de t2 en la dirección indicada por 0(t0).
    addi t0, t0, 4                    # suma el inmediato 4 a t0 y deja el resultado en t0.
    addi t1, t1, -1                   # suma el inmediato -1 a t1 y deja el resultado en t1.
    bnez t1, csf_loop                 # salta a csf_loop si t1 es distinto de cero.
    ret                               # retorna a la rutina que hizo la llamada.

# ===========================================================================
# clear_edit_area  — borra solo filas 0-22 (1840 celdas)
# ===========================================================================
clear_edit_area:
    li   t0, VGA_BUF                  # carga VGA_BUF en t0 para preparar una constante o dirección.
    li   t1, EDIT_CELLS               # carga EDIT_CELLS en t1 para preparar una constante o dirección.
    li   t2, ATTR_NORMAL              # carga ATTR_NORMAL en t2 para preparar una constante o dirección.
    ori  t2, t2, 0x20                 # activa o mezcla los bits de 0x20 sobre t2 y guarda el resultado en t2.
cea_loop:
    sw   t2, 0(t0)                    # guarda el valor de t2 en la dirección indicada por 0(t0).
    addi t0, t0, 4                    # suma el inmediato 4 a t0 y deja el resultado en t0.
    addi t1, t1, -1                   # suma el inmediato -1 a t1 y deja el resultado en t1.
    bnez t1, cea_loop                 # salta a cea_loop si t1 es distinto de cero.
    ret                               # retorna a la rutina que hizo la llamada.

# ===========================================================================
# update_cursor_hw  — escribe posición y blink_en en VGA_CTRL
#   VGA_CTRL[6:0]  = cursor_col
#   VGA_CTRL[12:8] = cursor_row
#   VGA_CTRL[16]   = blink_en = 1
# ===========================================================================
update_cursor_hw:
    li   t0, VGA_CTRL                 # carga VGA_CTRL en t0 para preparar una constante o dirección.
    lui  t1, 1               # t1 = 0x00010000 → bit16=1 (blink_en)
    slli t2, s1, 8           # row → bits [12:8]
    or   t1, t1, t2                   # combina por OR t1 y t2 para armar el valor final en t1.
    or   t1, t1, s0          # col → bits [6:0]
    sw   t1, 0(t0)                    # guarda el valor de t1 en la dirección indicada por 0(t0).
    ret                               # retorna a la rutina que hizo la llamada.

# ===========================================================================
# draw_status_bar — redibuja fila 23 completa con video inverso
#   Formato: "INSERT  R:C  [no name]" o "COMMAND  R:C  [no name]"
# ===========================================================================
draw_status_bar:
    addi sp, sp, -4                   # suma el inmediato -4 a sp y deja el resultado en sp.
    sw   ra, 0(sp)                    # guarda el valor de ra en la dirección indicada por 0(sp).

    # Calcular base de fila 23: VGA_BUF + EDIT_CELLS*4
    li   t0, VGA_BUF                  # carga VGA_BUF en t0 para preparar una constante o dirección.
    li   t1, EDIT_CELLS               # carga EDIT_CELLS en t1 para preparar una constante o dirección.
    slli t1, t1, 2                    # desplaza t1 a la izquierda 2 bits; se usa para multiplicar por potencias de dos.
    add  t0, t0, t1           # t0 = inicio fila 23

    # Limpiar los 80 celdas con espacio+video-inverso
    li   t1, COLS                     # carga COLS en t1 para preparar una constante o dirección.
    li   t2, ATTR_INVERSE             # carga ATTR_INVERSE en t2 para preparar una constante o dirección.
    ori  t2, t2, 0x20                 # activa o mezcla los bits de 0x20 sobre t2 y guarda el resultado en t2.
    mv   a1, t0               # a1 = cursor de escritura fila 23
dsb_clear:
    sw   t2, 0(a1)                    # guarda el valor de t2 en la dirección indicada por 0(a1).
    addi a1, a1, 4                    # suma el inmediato 4 a a1 y deja el resultado en a1.
    addi t1, t1, -1                   # suma el inmediato -1 a t1 y deja el resultado en t1.
    bnez t1, dsb_clear                # salta a dsb_clear si t1 es distinto de cero.

    # Volver al inicio para escribir contenido
    mv   a1, t0                       # copia el valor de t0 hacia a1.

    # Modo
    beqz s2, dsb_insert               # salta a dsb_insert si s2 vale cero.
    jal  ra, write_str_command        # llama a write_str_command y guarda la dirección de retorno en ra.
    j    dsb_after_mode               # salta directamente a dsb_after_mode sin guardar retorno.
dsb_insert:
    jal  ra, write_str_insert         # llama a write_str_insert y guarda la dirección de retorno en ra.
dsb_after_mode:

    li   a0, 0x20                     # carga 0x20 en a0 para preparar una constante o dirección.
    jal  ra, status_putc              # llama a status_putc y guarda la dirección de retorno en ra.
    li   a0, 0x20                     # carga 0x20 en a0 para preparar una constante o dirección.
    jal  ra, status_putc              # llama a status_putc y guarda la dirección de retorno en ra.

    # Fila:columna
    mv   a0, s1                       # copia el valor de s1 hacia a0.
    jal  ra, status_put_dec           # llama a status_put_dec y guarda la dirección de retorno en ra.
    li   a0, 0x3A             # ':'
    jal  ra, status_putc              # llama a status_putc y guarda la dirección de retorno en ra.
    mv   a0, s0                       # copia el valor de s0 hacia a0.
    jal  ra, status_put_dec           # llama a status_put_dec y guarda la dirección de retorno en ra.

    li   a0, 0x20                     # carga 0x20 en a0 para preparar una constante o dirección.
    jal  ra, status_putc              # llama a status_putc y guarda la dirección de retorno en ra.
    li   a0, 0x20                     # carga 0x20 en a0 para preparar una constante o dirección.
    jal  ra, status_putc              # llama a status_putc y guarda la dirección de retorno en ra.

    # "[no name]"
    li   a0, 0x5B; jal ra, status_putc   # [
    li   a0, 0x6E; jal ra, status_putc   # n
    li   a0, 0x6F; jal ra, status_putc   # o
    li   a0, 0x20; jal ra, status_putc   # (espacio)
    li   a0, 0x6E; jal ra, status_putc   # n
    li   a0, 0x61; jal ra, status_putc   # a
    li   a0, 0x6D; jal ra, status_putc   # m
    li   a0, 0x65; jal ra, status_putc   # e
    li   a0, 0x5D; jal ra, status_putc   # ]

    lw   ra, 0(sp)                    # lee una palabra de 32 bits desde 0(sp) y la deja en ra.
    addi sp, sp, 4                    # suma el inmediato 4 a sp y deja el resultado en sp.
    ret                               # retorna a la rutina que hizo la llamada.

# ---------------------------------------------------------------------------
# write_str_insert / write_str_command
#   Escriben "INSERT" o "COMMAND" en la barra de estado.
#   a1 avanza con cada carácter.
# ---------------------------------------------------------------------------
write_str_insert:
    addi sp, sp, -4                   # suma el inmediato -4 a sp y deja el resultado en sp.
    sw   ra, 0(sp)                    # guarda el valor de ra en la dirección indicada por 0(sp).
    li   a0, 'I'; jal ra, status_putc # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   a0, 'N'; jal ra, status_putc # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   a0, 'S'; jal ra, status_putc # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   a0, 'E'; jal ra, status_putc # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   a0, 'R'; jal ra, status_putc # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   a0, 'T'; jal ra, status_putc # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    lw   ra, 0(sp)                    # lee una palabra de 32 bits desde 0(sp) y la deja en ra.
    addi sp, sp, 4                    # suma el inmediato 4 a sp y deja el resultado en sp.
    ret                               # retorna a la rutina que hizo la llamada.

write_str_command:
    addi sp, sp, -4                   # suma el inmediato -4 a sp y deja el resultado en sp.
    sw   ra, 0(sp)                    # guarda el valor de ra en la dirección indicada por 0(sp).
    li   a0, 'C'; jal ra, status_putc # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   a0, 'O'; jal ra, status_putc # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   a0, 'M'; jal ra, status_putc # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   a0, 'M'; jal ra, status_putc # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   a0, 'A'; jal ra, status_putc # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   a0, 'N'; jal ra, status_putc # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   a0, 'D'; jal ra, status_putc # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    lw   ra, 0(sp)                    # lee una palabra de 32 bits desde 0(sp) y la deja en ra.
    addi sp, sp, 4                    # suma el inmediato 4 a sp y deja el resultado en sp.
    ret                               # retorna a la rutina que hizo la llamada.

# ---------------------------------------------------------------------------
# status_putc  — escribe ASCII a0 en la celda a1 con video inverso; a1 += 4
# ---------------------------------------------------------------------------
status_putc:
    li   t0, ATTR_INVERSE             # carga ATTR_INVERSE en t0 para preparar una constante o dirección.
    or   t0, t0, a0                   # combina por OR t0 y a0 para armar el valor final en t0.
    sw   t0, 0(a1)                    # guarda el valor de t0 en la dirección indicada por 0(a1).
    addi a1, a1, 4                    # suma el inmediato 4 a a1 y deja el resultado en a1.
    ret                               # retorna a la rutina que hizo la llamada.

# ---------------------------------------------------------------------------
# status_put_dec  — escribe a0 (0-99) en decimal en la barra de estado
# ---------------------------------------------------------------------------
status_put_dec:
    addi sp, sp, -8                   # suma el inmediato -8 a sp y deja el resultado en sp.
    sw   ra, 0(sp)                    # guarda el valor de ra en la dirección indicada por 0(sp).
    sw   s5, 4(sp)                    # guarda el valor de s5 en la dirección indicada por 4(sp).
    mv   s5, a0                       # copia el valor de a0 hacia s5.

    li   t0, 10                       # carga 10 en t0 para preparar una constante o dirección.
    blt  s5, t0, spd_one_digit        # salta a spd_one_digit si s5 es menor que t0.

    li   t1, 0                        # carga 0 en t1 para preparar una constante o dirección.
spd_tens_loop:
    blt  s5, t0, spd_tens_done        # salta a spd_tens_done si s5 es menor que t0.
    sub  s5, s5, t0                   # resta t0 a s5 y guarda el resultado en s5.
    addi t1, t1, 1                    # suma el inmediato 1 a t1 y deja el resultado en t1.
    j    spd_tens_loop                # salta directamente a spd_tens_loop sin guardar retorno.
spd_tens_done:
    addi a0, t1, 0x30                 # suma el inmediato 0x30 a t1 y deja el resultado en a0.
    jal  ra, status_putc              # llama a status_putc y guarda la dirección de retorno en ra.
    addi a0, s5, 0x30                 # suma el inmediato 0x30 a s5 y deja el resultado en a0.
    jal  ra, status_putc              # llama a status_putc y guarda la dirección de retorno en ra.
    j    spd_done                     # salta directamente a spd_done sin guardar retorno.

spd_one_digit:
    addi a0, s5, 0x30                 # suma el inmediato 0x30 a s5 y deja el resultado en a0.
    jal  ra, status_putc              # llama a status_putc y guarda la dirección de retorno en ra.

spd_done:
    lw   s5, 4(sp)                    # lee una palabra de 32 bits desde 4(sp) y la deja en s5.
    lw   ra, 0(sp)                    # lee una palabra de 32 bits desde 0(sp) y la deja en ra.
    addi sp, sp, 8                    # suma el inmediato 8 a sp y deja el resultado en sp.
    ret                               # retorna a la rutina que hizo la llamada.

# ===========================================================================
# handle_ps2  — lee un scancode de PS2_RX y lo procesa
# ===========================================================================
handle_ps2:
    addi sp, sp, -4                   # suma el inmediato -4 a sp y deja el resultado en sp.
    sw   ra, 0(sp)                    # guarda el valor de ra en la dirección indicada por 0(sp).

    li   t0, PS2_RX                   # carga PS2_RX en t0 para preparar una constante o dirección.
    lw   a0, 0(t0)                    # lee una palabra de 32 bits desde 0(t0) y la deja en a0.
    andi a0, a0, 0xFF                 # aplica una máscara AND con 0xFF para conservar solo los bits necesarios en a0.

    li   t1, PREFIX_BREAK             # carga PREFIX_BREAK en t1 para preparar una constante o dirección.
    beq  a0, t1, hp_set_break         # salta a hp_set_break si a0 y t1 son iguales.
    li   t1, PREFIX_EXT               # carga PREFIX_EXT en t1 para preparar una constante o dirección.
    beq  a0, t1, hp_set_ext           # salta a hp_set_ext si a0 y t1 son iguales.

    li   t1, 1                        # carga 1 en t1 para preparar una constante o dirección.
    beq  s3, t1, hp_break_key       # era break: revisar si se soltó Shift

    li   t1, 2                        # carga 2 en t1 para preparar una constante o dirección.
    beq  s3, t1, hp_extended        # era extended: procesar como flecha

    # make code normal: primero detectar Shift para guardarlo como modificador
    li   t1, SC_SHIFT_L               # carga SC_SHIFT_L en t1 para preparar una constante o dirección.
    beq  a0, t1, hp_shift_make        # salta a hp_shift_make si a0 y t1 son iguales.
    li   t1, SC_SHIFT_R               # carga SC_SHIFT_R en t1 para preparar una constante o dirección.
    beq  a0, t1, hp_shift_make        # salta a hp_shift_make si a0 y t1 son iguales.

    li   s3, 0                        # carga 0 en s3 para preparar una constante o dirección.
    beqz s2, hp_insert                # salta a hp_insert si s2 vale cero.
    jal  ra, handle_command_key       # llama a handle_command_key y guarda la dirección de retorno en ra.
    j    hp_redraw                    # salta directamente a hp_redraw sin guardar retorno.

hp_insert:
    jal  ra, handle_insert_key        # llama a handle_insert_key y guarda la dirección de retorno en ra.
    j    hp_redraw                    # salta directamente a hp_redraw sin guardar retorno.

hp_set_break:
    li   s3, 1                        # carga 1 en s3 para preparar una constante o dirección.
    j    hp_done                      # salta directamente a hp_done sin guardar retorno.
hp_set_ext:
    li   s3, 2                        # carga 2 en s3 para preparar una constante o dirección.
    j    hp_done                      # salta directamente a hp_done sin guardar retorno.
hp_shift_make:
    li   s5, 1                        # carga 1 en s5 para preparar una constante o dirección.
    li   s3, 0                        # carga 0 en s3 para preparar una constante o dirección.
    j    hp_done                      # salta directamente a hp_done sin guardar retorno.
hp_break_key:
    li   s3, 0                        # carga 0 en s3 para preparar una constante o dirección.
    li   t1, SC_SHIFT_L               # carga SC_SHIFT_L en t1 para preparar una constante o dirección.
    beq  a0, t1, hp_shift_break       # salta a hp_shift_break si a0 y t1 son iguales.
    li   t1, SC_SHIFT_R               # carga SC_SHIFT_R en t1 para preparar una constante o dirección.
    beq  a0, t1, hp_shift_break       # salta a hp_shift_break si a0 y t1 son iguales.
    j    hp_done                      # salta directamente a hp_done sin guardar retorno.
hp_shift_break:
    li   s5, 0                        # carga 0 en s5 para preparar una constante o dirección.
    j    hp_done                      # salta directamente a hp_done sin guardar retorno.
hp_clear_prefix:
    li   s3, 0                        # carga 0 en s3 para preparar una constante o dirección.
    j    hp_done                      # salta directamente a hp_done sin guardar retorno.
hp_extended:
    li   s3, 0                        # carga 0 en s3 para preparar una constante o dirección.
    jal  ra, handle_arrow_key         # llama a handle_arrow_key y guarda la dirección de retorno en ra.
    j    hp_redraw                    # salta directamente a hp_redraw sin guardar retorno.

hp_redraw:
    jal  ra, draw_status_bar          # llama a draw_status_bar y guarda la dirección de retorno en ra.
    jal  ra, update_cursor_hw         # llama a update_cursor_hw y guarda la dirección de retorno en ra.
hp_done:
    lw   ra, 0(sp)                    # lee una palabra de 32 bits desde 0(sp) y la deja en ra.
    addi sp, sp, 4                    # suma el inmediato 4 a sp y deja el resultado en sp.
    ret                               # retorna a la rutina que hizo la llamada.

# ===========================================================================
# handle_arrow_key  — a0 = scancode extendido
# ===========================================================================
handle_arrow_key:
    li   t1, SC_UP;    beq a0, t1, hak_up # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   t1, SC_DOWN;  beq a0, t1, hak_down # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   t1, SC_LEFT;  beq a0, t1, hak_left # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   t1, SC_RIGHT; beq a0, t1, hak_right # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    ret                               # retorna a la rutina que hizo la llamada.
hak_up:
    beqz s1, hak_done                 # salta a hak_done si s1 vale cero.
    addi s1, s1, -1                   # suma el inmediato -1 a s1 y deja el resultado en s1.
    ret                               # retorna a la rutina que hizo la llamada.
hak_down:
    li   t0, ROWS                     # carga ROWS en t0 para preparar una constante o dirección.
    addi t0, t0, -1                   # suma el inmediato -1 a t0 y deja el resultado en t0.
    beq  s1, t0, hak_done             # salta a hak_done si s1 y t0 son iguales.
    addi s1, s1, 1                    # suma el inmediato 1 a s1 y deja el resultado en s1.
    ret                               # retorna a la rutina que hizo la llamada.
hak_left:
    beqz s0, hak_done                 # salta a hak_done si s0 vale cero.
    addi s0, s0, -1                   # suma el inmediato -1 a s0 y deja el resultado en s0.
    ret                               # retorna a la rutina que hizo la llamada.
hak_right:
    li   t0, COLS                     # carga COLS en t0 para preparar una constante o dirección.
    addi t0, t0, -1                   # suma el inmediato -1 a t0 y deja el resultado en t0.
    beq  s0, t0, hak_done             # salta a hak_done si s0 y t0 son iguales.
    addi s0, s0, 1                    # suma el inmediato 1 a s0 y deja el resultado en s0.
hak_done:
    ret                               # retorna a la rutina que hizo la llamada.

# ===========================================================================
# handle_insert_key  — a0 = make code, modo INSERT
# ===========================================================================
handle_insert_key:
    addi sp, sp, -4                   # suma el inmediato -4 a sp y deja el resultado en sp.
    sw   ra, 0(sp)                    # guarda el valor de ra en la dirección indicada por 0(sp).

    li   t1, SC_ESC;       beq a0, t1, hik_to_command # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   t1, SC_ENTER;     beq a0, t1, hik_enter # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   t1, SC_BACKSPACE; beq a0, t1, hik_backspace # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.

    jal  ra, scancode_to_ascii        # llama a scancode_to_ascii y guarda la dirección de retorno en ra.
    beqz a0, hik_done                 # salta a hik_done si a0 vale cero.

    jal  ra, write_char_at_cursor     # llama a write_char_at_cursor y guarda la dirección de retorno en ra.

    addi s0, s0, 1                    # suma el inmediato 1 a s0 y deja el resultado en s0.
    li   t0, COLS                     # carga COLS en t0 para preparar una constante o dirección.
    blt  s0, t0, hik_done             # salta a hik_done si s0 es menor que t0.
    li   s0, 0                        # carga 0 en s0 para preparar una constante o dirección.
    addi s1, s1, 1                    # suma el inmediato 1 a s1 y deja el resultado en s1.
    li   t0, ROWS                     # carga ROWS en t0 para preparar una constante o dirección.
    blt  s1, t0, hik_done             # salta a hik_done si s1 es menor que t0.
    li   s1, 0              # wrap a fila 0
    j    hik_done                     # salta directamente a hik_done sin guardar retorno.

hik_to_command:
    li   s2, MODE_COMMAND             # carga MODE_COMMAND en s2 para preparar una constante o dirección.
    li   s4, 0                        # carga 0 en s4 para preparar una constante o dirección.
    j    hik_done                     # salta directamente a hik_done sin guardar retorno.

hik_enter:
    li   s0, 0                        # carga 0 en s0 para preparar una constante o dirección.
    addi s1, s1, 1                    # suma el inmediato 1 a s1 y deja el resultado en s1.
    li   t0, ROWS                     # carga ROWS en t0 para preparar una constante o dirección.
    blt  s1, t0, hik_done             # salta a hik_done si s1 es menor que t0.
    addi s1, t0, -1         # clamp a última fila
    j    hik_done                     # salta directamente a hik_done sin guardar retorno.

hik_backspace:
    beqz s0, hik_bs_row               # salta a hik_bs_row si s0 vale cero.
    addi s0, s0, -1                   # suma el inmediato -1 a s0 y deja el resultado en s0.
    j    hik_bs_erase                 # salta directamente a hik_bs_erase sin guardar retorno.
hik_bs_row:
    beqz s1, hik_done                 # salta a hik_done si s1 vale cero.
    addi s1, s1, -1                   # suma el inmediato -1 a s1 y deja el resultado en s1.
    li   t0, COLS                     # carga COLS en t0 para preparar una constante o dirección.
    addi s0, t0, -1                   # suma el inmediato -1 a t0 y deja el resultado en s0.
hik_bs_erase:
    jal  ra, erase_char_at_cursor     # llama a erase_char_at_cursor y guarda la dirección de retorno en ra.

hik_done:
    lw   ra, 0(sp)                    # lee una palabra de 32 bits desde 0(sp) y la deja en ra.
    addi sp, sp, 4                    # suma el inmediato 4 a sp y deja el resultado en sp.
    ret                               # retorna a la rutina que hizo la llamada.

# ===========================================================================
# handle_command_key  — a0 = make code, modo COMMAND
#   Secuencias reales: primero ':' (s4←1), luego w/r/q ejecutan el comando.
# ===========================================================================
handle_command_key:
    addi sp, sp, -4                   # suma el inmediato -4 a sp y deja el resultado en sp.
    sw   ra, 0(sp)                    # guarda el valor de ra en la dirección indicada por 0(sp).

    li   t1, SC_ESC;   beq a0, t1, hck_to_insert # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   t1, SC_I;     beq a0, t1, hck_to_insert # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   t1, SC_COLON; beq a0, t1, hck_set_colon # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.

    beqz s4, hck_done        # sin ':' pendiente: ignorar

    li   t1, SC_W; beq a0, t1, hck_save # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   t1, SC_R; beq a0, t1, hck_load # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li   t1, SC_Q; beq a0, t1, hck_quit # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.

    li   s4, 0               # tecla no reconocida tras ':': cancelar
    j    hck_done                     # salta directamente a hck_done sin guardar retorno.

hck_to_insert:
    li   s2, MODE_INSERT              # carga MODE_INSERT en s2 para preparar una constante o dirección.
    li   s4, 0                        # carga 0 en s4 para preparar una constante o dirección.
    j    hck_done                     # salta directamente a hck_done sin guardar retorno.
hck_set_colon:
    li   s4, 1                        # carga 1 en s4 para preparar una constante o dirección.
    j    hck_done                     # salta directamente a hck_done sin guardar retorno.
hck_save:
    li   s4, 0                        # carga 0 en s4 para preparar una constante o dirección.
    jal  ra, uart_save                # llama a uart_save y guarda la dirección de retorno en ra.
    j    hck_done                     # salta directamente a hck_done sin guardar retorno.
hck_load:
    li   s4, 0                        # carga 0 en s4 para preparar una constante o dirección.
    jal  ra, uart_load                # llama a uart_load y guarda la dirección de retorno en ra.
    j    hck_done                     # salta directamente a hck_done sin guardar retorno.
hck_quit:
    li   s4, 0                        # carga 0 en s4 para preparar una constante o dirección.
    jal  ra, clear_edit_area          # llama a clear_edit_area y guarda la dirección de retorno en ra.
    li   s0, 0                        # carga 0 en s0 para preparar una constante o dirección.
    li   s1, 0                        # carga 0 en s1 para preparar una constante o dirección.
    j    hck_done                     # salta directamente a hck_done sin guardar retorno.
hck_done:
    lw   ra, 0(sp)                    # lee una palabra de 32 bits desde 0(sp) y la deja en ra.
    addi sp, sp, 4                    # suma el inmediato 4 a sp y deja el resultado en sp.
    ret                               # retorna a la rutina que hizo la llamada.

# ===========================================================================
# write_char_at_cursor  — a0 = ASCII, escribe en (s1,s0) con ATTR_NORMAL
#   Dirección = VGA_BUF + (row*80 + col)*4
#   row*80 = (row<<6) + (row<<4)  (sin mul)
# ===========================================================================
write_char_at_cursor:
    slli t0, s1, 6                    # desplaza s1 a la izquierda 6 bits; se usa para multiplicar por potencias de dos.
    slli t1, s1, 4                    # desplaza s1 a la izquierda 4 bits; se usa para multiplicar por potencias de dos.
    add  t0, t0, t1                   # suma t0 con t1 y guarda el resultado en t0.
    add  t0, t0, s0                   # suma t0 con s0 y guarda el resultado en t0.
    slli t0, t0, 2                    # desplaza t0 a la izquierda 2 bits; se usa para multiplicar por potencias de dos.
    li   t1, VGA_BUF                  # carga VGA_BUF en t1 para preparar una constante o dirección.
    add  t1, t1, t0                   # suma t1 con t0 y guarda el resultado en t1.
    li   t2, ATTR_NORMAL              # carga ATTR_NORMAL en t2 para preparar una constante o dirección.
    or   t2, t2, a0                   # combina por OR t2 y a0 para armar el valor final en t2.
    sw   t2, 0(t1)                    # guarda el valor de t2 en la dirección indicada por 0(t1).
    ret                               # retorna a la rutina que hizo la llamada.

erase_char_at_cursor:
    addi sp, sp, -4                   # suma el inmediato -4 a sp y deja el resultado en sp.
    sw   ra, 0(sp)                    # guarda el valor de ra en la dirección indicada por 0(sp).
    li   a0, 0x20                     # carga 0x20 en a0 para preparar una constante o dirección.
    jal  ra, write_char_at_cursor     # llama a write_char_at_cursor y guarda la dirección de retorno en ra.
    lw   ra, 0(sp)                    # lee una palabra de 32 bits desde 0(sp) y la deja en ra.
    addi sp, sp, 4                    # suma el inmediato 4 a sp y deja el resultado en sp.
    ret                               # retorna a la rutina que hizo la llamada.

# ===========================================================================
# uart_save  — SOH + 1840 bytes de área de edición + EOT
# ===========================================================================
uart_save:
    addi sp, sp, -8                   # suma el inmediato -8 a sp y deja el resultado en sp.
    sw   ra, 0(sp)                    # guarda el valor de ra en la dirección indicada por 0(sp).
    sw   s5, 4(sp)                    # guarda el valor de s5 en la dirección indicada por 4(sp).

    li   a0, 0x01                     # carga 0x01 en a0 para preparar una constante o dirección.
    jal  ra, uart_send_byte           # llama a uart_send_byte y guarda la dirección de retorno en ra.

    li   s5, VGA_BUF                  # carga VGA_BUF en s5 para preparar una constante o dirección.
    li   t6, EDIT_CELLS               # carga EDIT_CELLS en t6 para preparar una constante o dirección.
us_loop:
    lw   t2, 0(s5)                    # lee una palabra de 32 bits desde 0(s5) y la deja en t2.
    andi a0, t2, 0xFF                 # aplica una máscara AND con 0xFF para conservar solo los bits necesarios en a0.
    jal  ra, uart_send_byte           # llama a uart_send_byte y guarda la dirección de retorno en ra.
    addi s5, s5, 4                    # suma el inmediato 4 a s5 y deja el resultado en s5.
    addi t6, t6, -1                   # suma el inmediato -1 a t6 y deja el resultado en t6.
    bnez t6, us_loop                  # salta a us_loop si t6 es distinto de cero.

    li   a0, 0x04                     # carga 0x04 en a0 para preparar una constante o dirección.
    jal  ra, uart_send_byte           # llama a uart_send_byte y guarda la dirección de retorno en ra.

    lw   s5, 4(sp)                    # lee una palabra de 32 bits desde 4(sp) y la deja en s5.
    lw   ra, 0(sp)                    # lee una palabra de 32 bits desde 0(sp) y la deja en ra.
    addi sp, sp, 8                    # suma el inmediato 8 a sp y deja el resultado en sp.
    ret                               # retorna a la rutina que hizo la llamada.

# ===========================================================================
# uart_load  — ENQ, espera SOH, recibe hasta EOT o 1840 bytes
# ===========================================================================
uart_load:
    addi sp, sp, -8                   # suma el inmediato -8 a sp y deja el resultado en sp.
    sw   ra, 0(sp)                    # guarda el valor de ra en la dirección indicada por 0(sp).
    sw   s5, 4(sp)                    # guarda el valor de s5 en la dirección indicada por 4(sp).

    li   a0, 0x05                     # carga 0x05 en a0 para preparar una constante o dirección.
    jal  ra, uart_send_byte           # llama a uart_send_byte y guarda la dirección de retorno en ra.

ul_wait_soh:
    jal  ra, uart_recv_byte           # llama a uart_recv_byte y guarda la dirección de retorno en ra.
    li   t0, 0x01                     # carga 0x01 en t0 para preparar una constante o dirección.
    bne  a0, t0, ul_wait_soh          # salta a ul_wait_soh si a0 y t0 son diferentes.

    jal  ra, clear_edit_area          # llama a clear_edit_area y guarda la dirección de retorno en ra.

    li   s5, VGA_BUF                  # carga VGA_BUF en s5 para preparar una constante o dirección.
    li   t6, EDIT_CELLS               # carga EDIT_CELLS en t6 para preparar una constante o dirección.
ul_recv_loop:
    beqz t6, ul_done                  # salta a ul_done si t6 vale cero.
    jal  ra, uart_recv_byte           # llama a uart_recv_byte y guarda la dirección de retorno en ra.
    li   t2, 0x04                     # carga 0x04 en t2 para preparar una constante o dirección.
    beq  a0, t2, ul_done              # salta a ul_done si a0 y t2 son iguales.
    li   t3, ATTR_NORMAL              # carga ATTR_NORMAL en t3 para preparar una constante o dirección.
    or   t2, a0, t3                   # combina por OR a0 y t3 para armar el valor final en t2.
    sw   t2, 0(s5)                    # guarda el valor de t2 en la dirección indicada por 0(s5).
    addi s5, s5, 4                    # suma el inmediato 4 a s5 y deja el resultado en s5.
    addi t6, t6, -1                   # suma el inmediato -1 a t6 y deja el resultado en t6.
    j    ul_recv_loop                 # salta directamente a ul_recv_loop sin guardar retorno.

ul_done:
    li   s0, 0                        # carga 0 en s0 para preparar una constante o dirección.
    li   s1, 0                        # carga 0 en s1 para preparar una constante o dirección.
    lw   s5, 4(sp)                    # lee una palabra de 32 bits desde 4(sp) y la deja en s5.
    lw   ra, 0(sp)                    # lee una palabra de 32 bits desde 0(sp) y la deja en ra.
    addi sp, sp, 8                    # suma el inmediato 8 a sp y deja el resultado en sp.
    ret                               # retorna a la rutina que hizo la llamada.

# ===========================================================================
# uart_send_byte  — a0 = byte; espera tx_ready (bit0 de UART_CTRL)
# ===========================================================================
uart_send_byte:
    li   t0, UART_CTRL                # carga UART_CTRL en t0 para preparar una constante o dirección.
usb_wait:
    lw   t1, 0(t0)                    # lee una palabra de 32 bits desde 0(t0) y la deja en t1.
    andi t1, t1, 1                    # aplica una máscara AND con 1 para conservar solo los bits necesarios en t1.
    beqz t1, usb_wait                 # salta a usb_wait si t1 vale cero.
    li   t0, UART_TX                  # carga UART_TX en t0 para preparar una constante o dirección.
    sw   a0, 0(t0)                    # guarda el valor de a0 en la dirección indicada por 0(t0).
    ret                               # retorna a la rutina que hizo la llamada.

# ===========================================================================
# uart_recv_byte  — espera rx_ready (bit1 de UART_CTRL); retorna byte en a0
# ===========================================================================
uart_recv_byte:
    li   t0, UART_CTRL                # carga UART_CTRL en t0 para preparar una constante o dirección.
urb_wait:
    lw   t1, 0(t0)                    # lee una palabra de 32 bits desde 0(t0) y la deja en t1.
    andi t1, t1, 2                    # aplica una máscara AND con 2 para conservar solo los bits necesarios en t1.
    beqz t1, urb_wait                 # salta a urb_wait si t1 vale cero.
    li   t0, UART_RX                  # carga UART_RX en t0 para preparar una constante o dirección.
    lw   a0, 0(t0)                    # lee una palabra de 32 bits desde 0(t0) y la deja en a0.
    andi a0, a0, 0xFF                 # aplica una máscara AND con 0xFF para conservar solo los bits necesarios en a0.
    ret                               # retorna a la rutina que hizo la llamada.

# ===========================================================================
# scancode_to_ascii  — a0 = make code Set 2 → a0 = ASCII imprimible, o 0
# Cadena de comparaciones (sin tabla en ROM; el bus de datos no alcanza la ROM)
# ===========================================================================
scancode_to_ascii:
    li t1, 0x1C; beq a0, t1, s2a_a    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x32; beq a0, t1, s2a_b    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x21; beq a0, t1, s2a_c    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x23; beq a0, t1, s2a_d    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x24; beq a0, t1, s2a_e    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x2B; beq a0, t1, s2a_f    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x34; beq a0, t1, s2a_g    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x33; beq a0, t1, s2a_h    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x43; beq a0, t1, s2a_i    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x3B; beq a0, t1, s2a_j    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x42; beq a0, t1, s2a_k    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x4B; beq a0, t1, s2a_l    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x3A; beq a0, t1, s2a_m    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x31; beq a0, t1, s2a_n    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x44; beq a0, t1, s2a_o    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x4D; beq a0, t1, s2a_p    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x15; beq a0, t1, s2a_q    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x2D; beq a0, t1, s2a_r    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x1B; beq a0, t1, s2a_s    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x2C; beq a0, t1, s2a_t    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x3C; beq a0, t1, s2a_u    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x2A; beq a0, t1, s2a_v    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x1D; beq a0, t1, s2a_w    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x22; beq a0, t1, s2a_x    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x35; beq a0, t1, s2a_y    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x1A; beq a0, t1, s2a_z    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x45; beq a0, t1, s2a_0    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x16; beq a0, t1, s2a_1    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x1E; beq a0, t1, s2a_2    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x26; beq a0, t1, s2a_3    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x25; beq a0, t1, s2a_4    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x2E; beq a0, t1, s2a_5    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x36; beq a0, t1, s2a_6    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x3D; beq a0, t1, s2a_7    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x3E; beq a0, t1, s2a_8    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x46; beq a0, t1, s2a_9    # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x29; beq a0, t1, s2a_space # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x41; beq a0, t1, s2a_comma # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x49; beq a0, t1, s2a_period # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, SC_COLON; beq a0, t1, s2a_semicolon # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x4A; beq a0, t1, s2a_slash # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    li t1, 0x4E; beq a0, t1, s2a_minus # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.

    li  a0, 0                         # carga 0 en a0 para preparar una constante o dirección.
    ret                               # retorna a la rutina que hizo la llamada.

s2a_a: li a0, 'a'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_b: li a0, 'b'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_c: li a0, 'c'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_d: li a0, 'd'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_e: li a0, 'e'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_f: li a0, 'f'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_g: li a0, 'g'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_h: li a0, 'h'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_i: li a0, 'i'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_j: li a0, 'j'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_k: li a0, 'k'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_l: li a0, 'l'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_m: li a0, 'm'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_n: li a0, 'n'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_o: li a0, 'o'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_p: li a0, 'p'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_q: li a0, 'q'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_r: li a0, 'r'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_s: li a0, 's'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_t: li a0, 't'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_u: li a0, 'u'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_v: li a0, 'v'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_w: li a0, 'w'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_x: li a0, 'x'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_y: li a0, 'y'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_z: li a0, 'z'; j s2a_apply_letter_shift # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.

s2a_apply_letter_shift:
    beqz s5, s2a_ret                  # salta a s2a_ret si s5 vale cero.
    addi a0, a0, -32       # 'a'..'z' -> 'A'..'Z'
s2a_ret:
    ret                               # retorna a la rutina que hizo la llamada.

s2a_0: li a0, '0'; ret                # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_1: li a0, '1'; ret                # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_2: li a0, '2'; ret                # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_3: li a0, '3'; ret                # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_4: li a0, '4'; ret                # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_5: li a0, '5'; ret                # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_6: li a0, '6'; ret                # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_7: li a0, '7'; ret                # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_8: li a0, '8'; ret                # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_9: li a0, '9'; ret                # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_space:     li a0, ' ';  ret       # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_comma:     li a0, ',';  ret       # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_period:    li a0, '.';  ret       # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_semicolon:
    beqz s5, s2a_semicolon_plain      # salta a s2a_semicolon_plain si s5 vale cero.
    li   a0, ':'                      # carga ':' en a0 para preparar una constante o dirección.
    ret                               # retorna a la rutina que hizo la llamada.
s2a_semicolon_plain:
    li   a0, ';'                      # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
    ret                               # retorna a la rutina que hizo la llamada.
s2a_slash:     li a0, '/';  ret       # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
s2a_minus:     li a0, '-';  ret       # se ejecutan instrucciones compactas de escritura/llamada en la barra de estado.
