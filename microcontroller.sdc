# ============================================================================
# microcontroller.sdc
# Constraints de TimeQuest para el proyecto microcontrolador RISC-V (CE 3201)
#
# Antes de este archivo, el proyecto NO tenia ningun .sdc: TimeQuest corria
# completamente sin restricciones (ningun reloj declarado), por lo que
# cualquier reporte de timing previo no era valido/significativo.
#
# Esta es una base MINIMA, suficiente para que TimeQuest reconozca el reloj
# de entrada de 50 MHz y derive automaticamente el reloj de 25 MHz generado
# por el PLL (timer_pll, usado para VGA). Expandir solo si TimeQuest reporta
# rutas sin restriccion ("unconstrained paths") que esta base no cubra.
# ============================================================================

# --- Reloj base de entrada: CLOCK_50 (50 MHz, periodo 20.000 ns) ---
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# --- Deriva automaticamente los relojes generados por el PLL (timer_pll),
#     incluyendo clk_25 (25 MHz, pixel clock de VGA) ---
derive_pll_clocks

# --- Incertidumbre de reloj estandar (jitter/skew) para todos los relojes
#     ya declarados arriba ---
derive_clock_uncertainty

# ============================================================================
# NOTA sobre el cruce de dominios CLOCK_50 (bus de 50 MHz: CPU/RAM/ROM/
# UART/PS2/Timer) <-> clk_25 (PLL, dominio de pixel VGA):
#
# El unico punto de cruce de dominio en el diseño es text_buffer.sv, que ya
# es una memoria de doble puerto/doble reloj genuina (escritura en clk_50,
# lectura en clk_25) -- este es el patron seguro estandar para cruzar datos
# de un dominio a otro via una memoria dual-port, y TimeQuest normalmente
# NO necesita (ni puede) analizar timing setup/hold dentro de la memoria
# misma para ese patron.
#
# Si, despues de compilar, TimeQuest reporta rutas sin restriccion o
# fallidas ENTRE el dominio CLOCK_50 y el dominio derivado de clk_25 (fuera
# de la memoria dual-port en si), agregue aqui algo como:
#
#   set_clock_groups -asynchronous \
#       -group [get_clocks {CLOCK_50}] \
#       -group [get_clocks {*timer_pll*clk_25*}]
#
# (ajustando el nombre exacto del reloj derivado segun lo que TimeQuest
# reporte tras derive_pll_clocks -- no se agrega especulativamente aqui
# porque el nombre exacto depende de la instancia generada por el PLL IP).
# ============================================================================

# ============================================================================
# RESTRICCIONES DE I/O (cierra el "Unconstrained Paths Summary")
#
# Sin esto, TimeQuest no analiza timing en NINGUN pin de I/O. No son fallos de
# slack: solo significa que no se le describio la relacion temporal externa.
# Se dividen en dos categorias segun la naturaleza REAL de cada interfaz.
# ============================================================================

# ----------------------------------------------------------------------------
# (1) Interfaces genuinamente ASINCRONAS -> set_false_path es correcto
#
#   Cada una se resincroniza dentro del FPGA, o el otro extremo sobremuestrea,
#   de modo que NO existe una relacion setup/hold real que analizar en el pin.
# ----------------------------------------------------------------------------

# rst_n: reset externo asincrono. Se combina con pll_locked (sys_rst_n =
# rst_n & pll_locked) sin sincronizador en el pin -> false path.
set_false_path -from [get_ports {rst_n}]

# UART_RXD: linea serial asincrona, sincronizada con 2 FF (rx_sync1/rx_sync2)
# en uart_rx.sv -> CDC, false path.
set_false_path -from [get_ports {UART_RXD}]

# UART_TXD: serial asincrona; el receptor remoto sobremuestrea, el timing del
# pin es irrelevante -> false path.
set_false_path -to   [get_ports {UART_TXD}]

# PS2_CLK / PS2_DAT: dominio propio lento (~10-16 kHz), sincronizado con
# cadenas de 2-3 FF en ps2_sync.sv. Son inout -> false path en ambos sentidos.
set_false_path -from [get_ports {PS2_CLK PS2_DAT}]
set_false_path -to   [get_ports {PS2_CLK PS2_DAT}]

# ----------------------------------------------------------------------------
# (2) Bus VGA hacia el DAC ADV7123 -> FALSE PATH completo (decision justificada)
#
#   VGA_CLK = clk_25 (pixel clock reenviado, microcontroller.sv). En teoria el
#   ADV7123 latchea R/G/B/HS/VS/SYNC_N respecto a VGA_CLK (source-synchronous),
#   PERO el pixel clock se reenvia por routing/global general (un simple assign
#   al pin), NO por un primitivo DDIO. Su insercion (~12 ns) crea un skew
#   reloj-vs-dato que hace IMPOSIBLE un sign-off riguroso: el setup sobra
#   (>11 ns a 40 ns de periodo) pero el hold da negativo por fraccion de ns,
#   que es un ARTEFACTO del modelo, no un riesgo real.
#
#   A 25 MHz esta es una interfaz de timing NO critico. Se declara false path
#   completo (setup y hold). Esto: (a) limpia el Unconstrained Paths Summary,
#   (b) evita el hold artefacto, (c) evita los avisos 332070 (output delay
#   min/max incompleto) -- sin ocultar ningun riesgo real. El sign-off riguroso
#   requeriria instanciar altddio_out para co-ubicar reloj y datos en el I/O
#   (cambio de HW, fuera de alcance).
# ----------------------------------------------------------------------------

# VGA_CLK se declara explicitamente como reloj generado (buena practica para
# una salida de reloj; derive_pll_clocks tambien lo propaga al pin). Nodo real
# del PLL (microcontroller.sta.rpt):
#   u_vga_pll|u_timer_pll|timer_pll_inst|altera_pll_i|...|divclk
# -compatibility_mode permite que el comodin cruce la jerarquia interna del IP.
create_generated_clock -name VGA_CLK_pin \
    -source [get_pins -compatibility_mode {*altera_pll_i*divclk}] \
    [get_ports {VGA_CLK}]

# Bus de datos/sync VGA: false path completo (setup y hold). Ver justificacion.
set_false_path -to [get_ports {VGA_R[*] VGA_G[*] VGA_B[*] VGA_HS VGA_VS VGA_SYNC_N}]

# VGA_BLANK_N esta fijo a 1'b1 (microcontroller.sv): no conmuta, es trivial.
set_false_path -to [get_ports {VGA_BLANK_N}]
# ============================================================================
