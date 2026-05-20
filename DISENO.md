# DISENO.md — Microcontrolador RISC-V RV32I con Procesador de Texto

**Curso:** CE 3201 Taller de Diseño Digital — I Semestre 2026  
**Proyecto:** Microcontrolador RISC-V con procesador de texto  
**Equipo:** <!-- Nombres de los integrantes -->  
**Fecha:** <!-- Fecha de última actualización -->  
**Repositorio:** <!-- URL del repositorio GitLab -->

> Este documento debe completarse **antes de escribir cualquier línea de código HDL**.  
> Consulta `docs/guia_visual.md` para convenciones de diagramación y `docs/img/README.md` para nombres de archivos de imagen.

---

## 1. Metodología de diseño top-down

### 1.1 Descripción de la jerarquía de módulos

<!-- Explica brevemente cómo se aplicó el diseño modular top-down al sistema.
     Describe los niveles de jerarquía (nivel 1 → nivel 4) y por qué se eligió esa descomposición. -->

### 1.2 Criterios de descomposición modular

<!-- Describe los criterios usados para dividir el sistema en módulos:
     - Separación de responsabilidades (CPU, memoria, periféricos)
     - Independencia de interfaces
     - Reutilización y verificabilidad independiente
     - Coherencia con el mapa de memoria -->

---

## 2. Sistema completo integrado

### 2.1 Diagrama de nivel 1 — Vista de caja negra

<!-- Inserta la imagen: docs/img/nivel1_sistema.png -->

**Objetivo:** <!-- Qué resuelve el sistema completo -->

**Entradas:**

| Señal | Ancho | Función |
|-------|-------|---------|
| `clk_i` | 1 bit | Reloj principal del sistema (50 MHz) |
| `rst_i` | 1 bit | Reset activo en bajo |
| `uart_rx_i` | 1 bit | Línea de recepción UART desde PC |
| `ps2_clk_i` | 1 bit | Reloj del protocolo PS/2 |
| `ps2_data_i` | 1 bit | Datos del protocolo PS/2 |

**Salidas:**

| Señal | Ancho | Función |
|-------|-------|---------|
| `uart_tx_o` | 1 bit | Línea de transmisión UART hacia PC |
| `vga_hsync_o` | 1 bit | Sincronía horizontal VGA |
| `vga_vsync_o` | 1 bit | Sincronía vertical VGA |
| `vga_r_o` | 4 bits | Canal rojo VGA (paleta CGA) |
| `vga_g_o` | 4 bits | Canal verde VGA (paleta CGA) |
| `vga_b_o` | 4 bits | Canal azul VGA (paleta CGA) |

**Explicación general:**  
<!-- Describe en 2–3 oraciones qué hace el sistema completo desde la perspectiva del usuario -->

---

### 2.2 Diagrama de nivel 2 — Subsistemas internos

<!-- Inserta la imagen: docs/img/nivel2_sistema.png -->

**Explicación general del sistema:**  
<!-- Describe cómo interactúan los subsistemas entre sí -->

#### 2.2.1 CPU (RISC-V RV32I)

**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Explicación general:**  

#### 2.2.2 Memoria ROM

**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Explicación general:**  

#### 2.2.3 Memoria RAM

**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Explicación general:**  

#### 2.2.4 UART

**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Explicación general:**  

#### 2.2.5 PS/2

**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Explicación general:**  

#### 2.2.6 Timer

**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Explicación general:**  

#### 2.2.7 Controlador VGA

**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Explicación general:**  

---

### 2.3 Mapa de conexiones CPU – memorias – periféricos

<!-- Inserta la imagen: docs/img/mapa_conexiones.png -->

<!-- Describe brevemente los buses principales: bus de instrucciones, bus de datos y bus de periféricos -->

---

### 2.4 Mapa de memoria

| Región | Inicio | Fin | Tamaño | Descripción |
|--------|--------|-----|--------|-------------|
| ROM (programa) | `0x0000_0000` | `0x0000_1FFF` | 8 KB | Almacena el firmware en ensamblador RV32I. Vector de reset en `0x0000_0000`. |
| RAM (datos) | `0x0000_2000` | `0x0000_2FFF` | 4 KB | Memoria de datos de lectura/escritura |
| Espacio de periféricos | `0x0001_0000` | `0x0001_FFFF` | 64 KB | Registros de control/estado/datos de periféricos |

#### Registros de periféricos

| Periférico | Registro | Offset | Dirección absoluta |
|-----------|----------|--------|--------------------|
| UART | Control/Estado | `0x00` | `0x0001_0040` |
| UART | Datos TX | `0x04` | `0x0001_0044` |
| UART | Datos RX | `0x08` | `0x0001_0048` |
| PS/2 | Control/Estado | `0x00` | `0x0001_0050` |
| PS/2 | RX | `0x04` | `0x0001_0054` |
| PS/2 | TX | `0x08` | `0x0001_0058` |
| Timer | Control/Estado | `0x00` | `0x0001_0060` |
| Timer | Datos | `0x04` | `0x0001_0064` |
| VGA | Control/Cursor | `0x00` | `0x0001_0120` |
| VGA | Buffer de texto (80×24) | — | `0x0001_1000` – `0x0001_2DFF` |

---

### 2.5 Diagrama de nivel 3 del sistema — Integración con decodificador

<!-- Inserta la imagen: docs/img/nivel3_sistema.png -->

<!-- Describe el decodificador de direcciones, las señales de chip select (CS) por módulo
     y la generación del reloj de 25 MHz para VGA -->

---

## 3. CPU RISC-V RV32I

### 3.1 Diagrama de bloques — Nivel 3

<!-- Inserta la imagen: docs/img/cpu_nivel3.png -->

<!-- Describe los bloques funcionales: PC, banco de registros, unidad de instrucción/decodificación,
     ALU, unidad de control, extensión de signo, MUXes de selección -->

### 3.2 Ruta de datos (datapath)

<!-- Inserta la imagen: docs/img/cpu_datapath.png -->

<!-- Describe el flujo de señales para al menos 3 tipos de instrucción: tipo-R, load/store, branch -->

### 3.3 FSM de la unidad de control

<!-- Inserta la imagen: docs/img/cpu_control_fsm.png -->

<!-- Describe los estados, condiciones de transición y señales de control emitidas en cada estado -->

### 3.4 Tabla de señales de control por tipo de instrucción

| Instrucción | Tipo | RegWrite | MemRead | MemWrite | Branch | ALUSrc | ALUOp |
|-------------|------|----------|---------|----------|--------|--------|-------|
| `add` | R | 1 | 0 | 0 | 0 | 0 | <!-- --> |
| `addi` | I | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> |
| `lw` | I | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> |
| `sw` | S | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> |
| `beq` | B | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> |
| `jal` | J | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> |

### 3.5 Tabla de instrucciones RV32I implementadas

| Mnemónico | Tipo | opcode [6:0] | funct3 [2:0] | funct7 [6:0] | Descripción |
|-----------|------|-------------|-------------|-------------|-------------|
| `lw` | I | `0000011` | `010` | — | Carga palabra desde memoria |
| `sw` | S | `0100011` | `010` | — | Almacena palabra en memoria |
| `add` | R | `0110011` | `000` | `0000000` | Suma de registros |
| `sub` | R | `0110011` | `000` | `0100000` | Resta de registros |
| `and` | R | `0110011` | `111` | `0000000` | AND lógico |
| `or` | R | `0110011` | `110` | `0000000` | OR lógico |
| `xor` | R | `0110011` | `100` | `0000000` | XOR lógico |
| `sll` | R | `0110011` | `001` | `0000000` | Desplazamiento lógico izquierda |
| `srl` | R | `0110011` | `101` | `0000000` | Desplazamiento lógico derecha |
| `sra` | R | `0110011` | `101` | `0100000` | Desplazamiento aritmético derecha |
| `slt` | R | `0110011` | `010` | `0000000` | Set if less than (signed) |
| `sltu` | R | `0110011` | `011` | `0000000` | Set if less than (unsigned) |
| `addi` | I | `0010011` | `000` | — | Suma inmediato |
| `andi` | I | `0010011` | `111` | — | AND con inmediato |
| `ori` | I | `0010011` | `110` | — | OR con inmediato |
| `xori` | I | `0010011` | `100` | — | XOR con inmediato |
| `slli` | I | `0010011` | `001` | `0000000` | Desplazamiento lógico izq. inmediato |
| `srli` | I | `0010011` | `101` | `0000000` | Desplazamiento lógico der. inmediato |
| `srai` | I | `0010011` | `101` | `0100000` | Desplazamiento aritmético der. inmediato |
| `slti` | I | `0010011` | `010` | — | Set if less than inmediato (signed) |
| `sltui` | I | `0010011` | `011` | — | Set if less than inmediato (unsigned) |
| `beq` | B | `1100011` | `000` | — | Branch if equal |
| `bne` | B | `1100011` | `001` | — | Branch if not equal |
| `blt` | B | `1100011` | `100` | — | Branch if less than |
| `bge` | B | `1100011` | `101` | — | Branch if greater or equal |
| `jal` | J | `1101111` | — | — | Jump and link |
| `jalr` | I | `1100111` | `000` | — | Jump and link register |

### 3.6 Nivel 4 — Fichas de módulos del CPU

#### 3.6.1 Contador de Programa (PC)

**Nombre:** `program_counter`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 3.6.2 Banco de Registros

**Nombre:** `register_file`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 3.6.3 Unidad Aritmético-Lógica (ALU)

**Nombre:** `alu`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 3.6.4 Unidad de Control

**Nombre:** `control_unit`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 3.6.5 Extensión de Signo

**Nombre:** `sign_extend`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

---

## 4. Periférico UART

### 4.1 Diagrama de bloques — Nivel 3

<!-- Inserta la imagen: docs/img/uart_nivel3.png -->

### 4.2 FSM del UART

<!-- Inserta la imagen: docs/img/uart_fsm.png -->

### 4.3 Tabla de interfaz de puertos

| Puerto | Dirección | Ancho | Función |
|--------|-----------|-------|---------|
| `clk_i` | Entrada | 1 bit | Reloj del sistema (50 MHz) |
| `rst_i` | Entrada | 1 bit | Reset activo en bajo |
| `tx_data_i` | Entrada | 8 bits | Byte a transmitir |
| `tx_start_i` | Entrada | 1 bit | Inicia transmisión |
| `rx_i` | Entrada | 1 bit | Línea serial de recepción |
| `tx_o` | Salida | 1 bit | Línea serial de transmisión |
| `tx_ready_o` | Salida | 1 bit | Transmisor libre |
| `rx_ready_o` | Salida | 1 bit | Byte recibido disponible |
| `rx_data_o` | Salida | 8 bits | Byte recibido |

### 4.4 Nivel 4 — Fichas de módulos del UART

#### 4.4.1 Generador de baud rate

**Nombre:** `baud_gen`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:** Divisor de frecuencia: ⌊50 000 000 / 115 200⌋ = 434 ciclos por bit.  
**Justificación de diseño:**  

#### 4.4.2 Transmisor UART (TX)

**Nombre:** `uart_tx`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 4.4.3 Receptor UART (RX)

**Nombre:** `uart_rx`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

---

## 5. Periférico PS/2

### 5.1 Diagrama de bloques — Nivel 3

<!-- Inserta la imagen: docs/img/ps2_nivel3.png -->

### 5.2 FSM del PS/2

<!-- Inserta la imagen: docs/img/ps2_fsm.png -->

### 5.3 Tabla de interfaz de puertos

| Puerto | Dirección | Ancho | Función |
|--------|-----------|-------|---------|
| `clk_i` | Entrada | 1 bit | Reloj del sistema |
| `rst_i` | Entrada | 1 bit | Reset activo en bajo |
| `ps2_clk_i` | Entrada | 1 bit | Reloj PS/2 del teclado |
| `ps2_data_i` | Entrada | 1 bit | Datos PS/2 del teclado |
| `kbd_enable_i` | Entrada | 1 bit | Habilita recepción |
| `tx_data_i` | Entrada | 8 bits | Comando a enviar al teclado |
| `rx_ready_o` | Salida | 1 bit | Scancode disponible |
| `rx_data_o` | Salida | 8 bits | Byte de scancode recibido |
| `tx_ready_o` | Salida | 1 bit | Transmisor libre |
| `rx_error_o` | Salida | 1 bit | Error de paridad o enmarcado |
| `ps2_clk_o` | Salida | 1 bit | Reloj PS/2 (para TX) |
| `ps2_data_o` | Salida | 1 bit | Datos PS/2 (para TX) |

### 5.4 Nivel 4 — Fichas de módulos del PS/2

#### 5.4.1 Receptor PS/2

**Nombre:** `ps2_rx`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:** Captura los 11 bits de la trama PS/2 (start, 8 datos LSB-first, paridad impar, stop) en flanco descendente de `ps2_clk_i`. Verifica paridad. Maneja prefijos 0xF0 (break) y 0xE0 (extendida).  
**Justificación de diseño:**  

#### 5.4.2 Transmisor PS/2

**Nombre:** `ps2_tx`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

---

## 6. Periférico Timer

### 6.1 Diagrama de bloques — Nivel 3

<!-- Inserta la imagen: docs/img/timer_nivel3.png -->

### 6.2 FSM del Timer

<!-- Inserta la imagen -->

### 6.3 Tabla de interfaz de puertos

| Puerto | Dirección | Ancho | Función |
|--------|-----------|-------|---------|
| `clk_i` | Entrada | 1 bit | Reloj del sistema |
| `rst_i` | Entrada | 1 bit | Reset activo en bajo |
| `start_i` | Entrada | 1 bit | Habilita el conteo |
| `stop_i` | Entrada | 1 bit | Detiene el conteo |
| `clear_i` | Entrada | 1 bit | Reinicia al valor inicial |
| `autoreload_i` | Entrada | 1 bit | Habilita recarga automática |
| `load_val_i` | Entrada | 32 bits | Valor inicial del contador |
| `timeout_o` | Salida | 1 bit | Indica que el contador llegó a 0 |
| `count_o` | Salida | 32 bits | Valor actual del contador |

### 6.4 Nivel 4 — Fichas de módulos del Timer

#### 6.4.1 Contador de 32 bits

**Nombre:** `timer_counter`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

---

## 7. Controlador VGA

### 7.1 Diagrama de bloques — Nivel 3

<!-- Inserta la imagen: docs/img/vga_nivel3.png -->

### 7.2 Diagrama de timing VGA 640×480 @ 60 Hz

<!-- Inserta la imagen: docs/img/vga_timing.png -->

| Parámetro | Horizontal (píxeles) | Vertical (líneas) |
|-----------|---------------------|-------------------|
| Región activa | 640 | 480 |
| Front porch | 16 | 10 |
| Sync pulse | 96 | 2 |
| Back porch | 48 | 33 |
| **Total** | **800** | **525** |

Reloj de píxel: 25 MHz (generado por divisor de frecuencia o PLL desde 50 MHz).

### 7.3 Formato del buffer de texto

<!-- Inserta la imagen: docs/img/vga_text_mode.png -->

- Resolución en texto: 80 columnas × 24 filas
- Tamaño de glifo: 8×16 píxeles (Font ROM interna)
- Dirección de celda (col, fila): `0x0001_1000 + (fila × 80 + col) × 4`

| Bits | Campo | Descripción |
|------|-------|-------------|
| [7:0] | ASCII | Código ASCII del carácter a mostrar |
| [11:8] | Color frente | Paleta CGA de 4 bits |
| [15:12] | Color fondo | Paleta CGA de 4 bits |
| [31:16] | Reservado | Leer como 0, escrituras ignoradas |

### 7.4 Tabla de interfaz de puertos

| Puerto | Dirección | Ancho | Función |
|--------|-----------|-------|---------|
| `clk_25_i` | Entrada | 1 bit | Reloj de píxel (25 MHz) |
| `rst_i` | Entrada | 1 bit | Reset activo en bajo |
| `addr_i` | Entrada | 32 bits | Dirección de celda del buffer |
| `data_i` | Entrada | 32 bits | Dato a escribir en buffer |
| `we_i` | Entrada | 1 bit | Habilitación de escritura |
| `cursor_col_i` | Entrada | 7 bits | Columna del cursor (0–79) |
| `cursor_row_i` | Entrada | 5 bits | Fila del cursor (0–23) |
| `blink_en_i` | Entrada | 1 bit | Habilita parpadeo del cursor |
| `hsync_o` | Salida | 1 bit | Sincronía horizontal |
| `vsync_o` | Salida | 1 bit | Sincronía vertical |
| `r_o` | Salida | 4 bits | Canal rojo |
| `g_o` | Salida | 4 bits | Canal verde |
| `b_o` | Salida | 4 bits | Canal azul |

### 7.5 Nivel 4 — Fichas de módulos del controlador VGA

#### 7.5.1 Generador de timing H/V

**Nombre:** `vga_timing_gen`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 7.5.2 Lógica de acceso al buffer de texto

**Nombre:** `text_buffer`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 7.5.3 Font ROM

**Nombre:** `font_rom`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 7.5.4 Paleta CGA y lógica de color

**Nombre:** `cga_palette`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

---

## 8. Firmware — Editor de texto

### 8.1 Diagrama de flujo: Inicialización del sistema

<!-- Inserta la imagen: docs/img/fw_init.png -->

### 8.2 FSM de modos del editor

<!-- Inserta la imagen: docs/img/fw_editor_fsm.png -->

### 8.3 Diagrama de flujo: Bucle principal

<!-- Inserta la imagen: docs/img/fw_main_loop.png -->

### 8.4 Diagrama de flujo: Manejador de teclado PS/2

<!-- Inserta la imagen: docs/img/fw_ps2_handler.png -->

### 8.5 Diagrama de flujo: Actualización del buffer VGA

<!-- Incluido dentro del manejador de teclado o como diagrama separado -->

### 8.6 Diagrama de flujo: Protocolo UART (guardar/cargar)

<!-- Inserta la imagen: docs/img/fw_uart_protocol.png -->

---

## 9. Estrategia de verificación

### 9.1 CPU

| # | Señales de entrada | Comportamiento esperado | Criterio pass/fail | Testbench |
|---|--------------------|------------------------|--------------------|-----------|
| 1 | <!-- --> | <!-- --> | <!-- --> | `tb_cpu.sv` |
| 2 | <!-- --> | <!-- --> | <!-- --> | `tb_cpu.sv` |
| 3 | <!-- --> | <!-- --> | <!-- --> | `tb_cpu.sv` |

### 9.2 UART

| # | Señales de entrada | Comportamiento esperado | Criterio pass/fail | Testbench |
|---|--------------------|------------------------|--------------------|-----------|
| 1 | <!-- --> | <!-- --> | <!-- --> | `tb_uart.sv` |
| 2 | <!-- --> | <!-- --> | <!-- --> | `tb_uart.sv` |
| 3 | <!-- --> | <!-- --> | <!-- --> | `tb_uart.sv` |

### 9.3 PS/2

| # | Señales de entrada | Comportamiento esperado | Criterio pass/fail | Testbench |
|---|--------------------|------------------------|--------------------|-----------|
| 1 | <!-- --> | <!-- --> | <!-- --> | `tb_ps2.sv` |
| 2 | <!-- --> | <!-- --> | <!-- --> | `tb_ps2.sv` |
| 3 | <!-- --> | <!-- --> | <!-- --> | `tb_ps2.sv` |

### 9.4 Timer

| # | Señales de entrada | Comportamiento esperado | Criterio pass/fail | Testbench |
|---|--------------------|------------------------|--------------------|-----------|
| 1 | <!-- --> | <!-- --> | <!-- --> | `tb_timer.sv` |
| 2 | <!-- --> | <!-- --> | <!-- --> | `tb_timer.sv` |
| 3 | <!-- --> | <!-- --> | <!-- --> | `tb_timer.sv` |

### 9.5 VGA

| # | Señales de entrada | Comportamiento esperado | Criterio pass/fail | Testbench |
|---|--------------------|------------------------|--------------------|-----------|
| 1 | <!-- --> | <!-- --> | <!-- --> | `tb_vga.sv` |
| 2 | <!-- --> | <!-- --> | <!-- --> | `tb_vga.sv` |
| 3 | <!-- --> | <!-- --> | <!-- --> | `tb_vga.sv` |

---

## 10. Tabla de asignación de pines FPGA DE10-Standard

| Señal del diseño | Dirección | Pin físico FPGA | Estándar I/O | Comentario |
|-----------------|-----------|----------------|--------------|------------|
| `clk_i` | Entrada | <!-- --> | 3.3V LVTTL | Oscilador de 50 MHz |
| `rst_i` | Entrada | <!-- --> | 3.3V LVTTL | KEY[0] activo en bajo |
| `uart_rx_i` | Entrada | <!-- --> | 3.3V LVTTL | GPIO o conector USB-UART |
| `uart_tx_o` | Salida | <!-- --> | 3.3V LVTTL | GPIO o conector USB-UART |
| `ps2_clk_i` | Entrada | <!-- --> | 3.3V LVTTL | Conector PS/2 |
| `ps2_data_i` | Entrada | <!-- --> | 3.3V LVTTL | Conector PS/2 |
| `vga_hsync_o` | Salida | <!-- --> | 3.3V LVTTL | Conector VGA |
| `vga_vsync_o` | Salida | <!-- --> | 3.3V LVTTL | Conector VGA |
| `vga_r_o[3:0]` | Salida | <!-- --> | 3.3V LVTTL | Canal rojo VGA |
| `vga_g_o[3:0]` | Salida | <!-- --> | 3.3V LVTTL | Canal verde VGA |
| `vga_b_o[3:0]` | Salida | <!-- --> | 3.3V LVTTL | Canal azul VGA |

---

## 11. Alternativas de diseño

### 11.1 CPU: Uniciclo vs. Multiciclo

<!-- Inserta la imagen: docs/img/alt_cpu_unic_vs_multic.png -->

| Criterio | Uniciclo | Multiciclo |
|----------|----------|------------|
| CPI | 1 (siempre) | Variable (promedio < 1 uniciclo para instrucciones simples) |
| Complejidad de la unidad de control | Baja (lógica combinacional) | Alta (FSM de varios estados) |
| Uso de recursos (LUTs) | <!-- --> | <!-- --> |
| Latencia por instrucción | Limitada por la instrucción más lenta | Proporcional a la instrucción |
| Facilidad de verificación | Alta | Media |

**Alternativa seleccionada:** <!-- Uniciclo / Multiciclo -->  
**Justificación:** <!-- -->

### 11.2 Controlador PS/2: Alternativas

<!-- Inserta la imagen: docs/img/alt_ps2.png -->

| Criterio | FSM clásica | Contador de bits con shift register |
|----------|-------------|-------------------------------------|
| Complejidad | <!-- --> | <!-- --> |
| Uso de recursos | <!-- --> | <!-- --> |
| Manejo de errores | <!-- --> | <!-- --> |

**Alternativa seleccionada:** <!-- -->  
**Justificación:** <!-- -->

### 11.3 Renderizado VGA: Alternativas

<!-- Inserta la imagen: docs/img/alt_vga.png -->

| Criterio | Modo texto con Font ROM | Modo bitmap |
|----------|------------------------|-------------|
| Uso de memoria | <!-- --> | <!-- --> |
| Complejidad de la lógica de renderizado | <!-- --> | <!-- --> |
| Flexibilidad visual | <!-- --> | <!-- --> |

**Alternativa seleccionada:** <!-- -->  
**Justificación:** <!-- -->