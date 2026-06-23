# **Proyecto Final — CE 3201 Taller de Diseño Digital**
Instituto Tecnológico de Costa Rica

Semestre: I Semestre 2026

Profesor: Dr.-Ing. Jeferson González Gómez





Microcontrolador de 32 bits basado en el conjunto de instrucciones **RISC-V RV32I**,
descrito en SystemVerilog y sintetizable sobre la tarjeta **DE1-SoC**. Integra una jerarquía de memoria (ROM/RAM) y periféricos mapeados en
memoria (UART, PS/2, Timer y VGA) para ejecutar una aplicación de **editor de texto
interactivo** escrita en ensamblador RV32I.

---

## Integrantes


| Nombre | Carné |
|--------|-------|
| Guerrero Gonzalez Dylan Maximiliano  | 2022016016  |
| Hernandez Castillo Antony Javier   | 2022321746 |
| García Izaguirre José   | 2022437991  |

---

## Características del sistema

- **CPU:** RISC-V RV32I, uniciclo. Subconjunto: `lw, sw, sll(i), srl(i),
  sra(i), add, sub, and, or, xor, addi, andi, ori, xori, beq, bne, blt, bge, slt(i),
  sltu, sltiu, jal, jalr`.
- **Memoria (bloques M10K internos):**
  - **ROM de programa, 8 KB** — lectura registrada en **flanco de bajada**: la
    instrucción queda válida dentro del mismo ciclo, manteniendo el fetch uniciclo.
  - **RAM de datos, 4 KB** — lectura registrada en **flanco de subida** (M10K limpio,
    1 ciclo de latencia).
- **Latencia de `lw` (stall de 1 ciclo):** como la RAM M10K entrega el dato un ciclo
  después, el CPU inserta **un ciclo de espera en cada `lw`** mediante una FSM
  (`ST_IDLE → ST_LOAD_WAIT` en `cpu/riscv_cpu.sv`): mantiene el PC (`pc_en=0`) y
  bloquea la escritura del banco de registros en el primer ciclo, y escribe `rd` en el
  segundo cuando el dato ya es válido. **`lw` toma 2 ciclos; todo lo demás, 1 ciclo.**
  Esto permite usar M10K (denso) y que el diseño quepa en la FPGA.
- **Periféricos (mapeados en memoria):**
  - **UART** 115200-8N1 (comunicación con PC, protocolo de archivos).
  - **PS/2** bidireccional (teclado, trama de 11 bits, Set 2, paridad impar).
  - **Timer** programable de 32 bits (retardos, parpadeo del cursor).
  - **VGA** 640×480@60 Hz, modo texto 80×24 con font ROM y paleta CGA.
- **Relojes:** entrada de 50 MHz (`CLOCK_50`). El reloj de píxel de **25 MHz** del VGA
  se genera con un **PLL** (`timer_pll`, vía `timer_pll_wrapper`).
- **Reset:** global, **activo en bajo** (`rst_n`), consistente en todos los módulos.

---

## Arquitectura

```
                 ProgAddress / ProgIn  (ROM lee en negedge -> fetch uniciclo)
   ┌───────────┐ ◄───────────────────► ┌─────────┐
   │ riscv_cpu │                        │   rom   │ 8 KB
   │ (RV32I)   │  + FSM stall de 'lw'   └─────────┘
   │           │   DataAddress/Out/In/we
   └─────┬─────┘ ◄──────────┐
         │                  │
         ▼                  ▼
  ┌────────────────────┐   (mux de lectura → DataIn)
  │ address_translator │
  └───┬───┬───┬───┬────┘
  cs_ram │   │   │  cs_vga(ctrl|buffer)
      ▼  │   │   ▼
  ┌─────┐│   │ ┌────────────────┐
  │ ram ││   │ │ vga_controller │──► VGA (R,G,B,HS,VS)  (clk_25 ◄ PLL)
  └─────┘│   │ └────────────────┘
   cs_uart cs_ps2 cs_timer
      ▼     ▼     ▼
  ┌──────┐┌─────┐┌───────┐
  │ uart ││ ps2 ││ timer │
  └──┬───┘└──┬──┘└───────┘
   UART RX/TX  PS2 CLK/DAT
```

El `address_translator` decodifica el bus de datos y genera los *chip-selects* y la
dirección local. El dato de lectura hacia el CPU se construye en `microcontroller.sv`:
la RAM se prioriza con `cs_ram` y los periféricos (que devuelven 0 cuando no están
seleccionados) se combinan con OR.

---

## Mapa de memoria

| Región            | Rango                       | Tamaño |
|-------------------|-----------------------------|--------|
| ROM (programa)    | `0x0000_0000 – 0x0000_1FFF` | 8 KB   |
| RAM (datos)       | `0x0000_2000 – 0x0000_2FFF` | 4 KB   |
| Periféricos       | `0x0001_0000 – 0x0001_FFFF` | —      |

| Periférico        | Dirección base   |
|-------------------|------------------|
| UART (ctrl/tx/rx) | `0x0001_0040`    |
| PS/2 (ctrl/rx/tx) | `0x0001_0050`    |
| Timer (ctrl/data) | `0x0001_0060`    |
| VGA control/cursor| `0x0001_0120`    |
| Buffer de texto   | `0x0001_1000 – 0x0001_2DFF` |

---

## Estructura de directorios

```
proyecto-taller-digital/
├── microcontroller.sv          # TOP del sistema (SoC completo)
├── microcontroller.qpf/.qsf    # Proyecto y asignaciones de Quartus
├── rom.hex                     # Firmware del editor (cargado en la ROM)
├── .gitignore  /  README.md
├── cpu/                        # CPU RV32I: riscv_cpu (FSM stall lw), datapath,
│                               #   control_unit, alu, register_file, program_counter
│                               #   (con pc_en), sign_extend
├── Address Translator/         # Decodificación del bus de datos (splitter, decoders, mux)
├── rtl/peripherals/
│   ├── rom/   ram/             # Memorias M10K (ROM negedge / RAM posedge)
│   ├── uart/                   # baud_gen, uart_rx, uart_tx, uart_peripheral
│   ├── ps2/                    # sync, rx_frame, rx_fsm, parity_chk, tx, peripheral
│   ├── timer/                  # prescaler, counter, peripheral, pll_wrapper
│   └── vga/                    # timing_gen, text_buffer, font_rom, cga_palette,
│                               #   vga_clk_gen, vga_controller
├── tb/                         # Testbenches (ver "Verificación")
│   ├── tb_microcontroller_final.sv / _full_compact.sv   # sistema completo (RTL)
│   ├── tb_uart_peripheral.sv / tb_ps2_peripheral.sv     # periféricos (RTL)
│   ├── tb_cpu_gate.sv  (.do)                            # gate-level CPU
│   ├── tb_vga_gate.sv  (.do)                            # gate-level VGA
│   ├── sim_validacion_stall/                            # validación del stall de lw
│   │     tb_lw_stall.sv, tb_lw_stall2.sv, caso*.hex
│   └── timer/                                           # tb_timer_peripheral.sv
└── timer_pll/                  # IP del PLL generado por Quartus (25 MHz)
```

---

## Requisitos

- **Intel Quartus Prime Lite 18.0** (síntesis, dispositivo `5CSEMA5F31C6`).
- **ModelSim - Intel FPGA Edition** (simulación SystemVerilog).
- Ensamblador RV32I / Ripes (para generar `rom.hex` con el firmware del editor).
- Python (para realizar lectura del puerto USB y poder recibir y enviar archivos por UART)

---

## Síntesis (Quartus)

1. Abrir `microcontroller.qpf` en Quartus Prime Lite.
2. Verificar que el TOP y el IP están en el `.qsf`:
   ```tcl
   set_global_assignment -name SYSTEMVERILOG_FILE microcontroller.sv
   set_global_assignment -name QIP_FILE timer_pll.qip
   ```
3. **Pines de la DE1-SoC: ya asignados** en el `.qsf` (3.3-V LVTTL):
   `CLOCK_50` (PIN_AF14), `rst_n` (KEY[0], PIN_AA14), `PS2_CLK/PS2_DAT`,
   `UART_RXD/UART_TXD`, y el bus `VGA_R/G/B[7:0]` + `VGA_HS/VS/CLK/BLANK_N/SYNC_N`.
4. Firmware: el top usa `parameter ROM_INIT_FILE = "rom.hex"`; colocar `rom.hex` en la
   carpeta del proyecto.
5. **Processing → Start Compilation** y programar el `.sof` con el **Programmer**.
---

## Verificación

Estrategia por capas (todas autoverificables con reportes PASS/FAIL):

| Nivel | Testbench | Qué cubre |
|-------|-----------|-----------|
| RTL — sistema   | `tb/tb_microcontroller_final.sv`, `tb_microcontroller_full_compact.sv` | CPU + memorias + traductor + periféricos integrados |
| RTL — periférico| `tb/tb_uart_peripheral.sv`, `tb/tb_ps2_peripheral.sv`, `tb/timer/tb_timer_peripheral.sv` | protocolo UART / PS/2 / Timer |
| RTL — stall `lw`| `tb/sim_validacion_stall/tb_lw_stall*.sv` (+ `caso*.hex`) | latencia de `lw` con RAM M10K (pila/subrutinas) |
| Gate-level (post-síntesis) | `tb/tb_cpu_gate.sv` (`.do`), `tb/tb_vga_gate.sv` (`.do`) | CPU y VGA sobre el netlist sintetizado |

**RTL (módulo, ejemplo):**
```sh
vlib work
vlog -sv rtl/peripherals/timer/timer_prescaler.sv rtl/peripherals/timer/timer_counter.sv \
        rtl/peripherals/timer/timer_peripheral.sv tb/timer/tb_timer_peripheral.sv
vsim -c -do "run -all; quit -f" tb_timer_peripheral
```

**RTL (sistema):** compilar todas las fuentes con `+define+SIMULATION` (el
`timer_pll_wrapper` usa un modelo *bypass* del PLL) y correr `tb_microcontroller_final`.
En modo bypass el reloj de píxel queda a 50 MHz en simulación; la frecuencia real de
25 MHz solo aplica en hardware con el IP generado.

**Gate-level (post-síntesis):** se usan testbenches **por módulo** (`tb_cpu_gate`,
`tb_vga_gate`) con sus scripts `.do`. En **ModelSim Starter Edition (gratuita)** el
sistema completo no se puede simular a nivel de compuertas porque el **PLL y celdas de
reloj de Cyclone V están encriptados** y el netlist completo excede la capacidad de la
edición gratuita; por eso la verificación gate-level se hace por módulo (CPU, VGA), que
no contienen IP encriptado. Con **Questa/ModelSim completo** sí corre el netlist
completo (con `-L cyclonev_ver -L altera_ver -L altera_lnsim_ver`).

---

## Aplicación: editor de texto

Editor interactivo estilo *vim*, con dos modos:

- **Modo inserción** (por defecto): caracteres imprimibles se insertan en el cursor;
  `Enter`, `Backspace`, flechas y `Esc` (→ modo comando).
- **Modo comando:** `i` (insertar), `:w` (guardar a PC vía UART), `:r` (cargar desde
  PC), `:q` (limpiar buffer), flechas (mover cursor).

**Protocolo de archivos UART (115200-8N1):** Guardar = `SOH(0x01)` + contenido +
`EOT(0x04)`; Cargar = `ENQ(0x05)` y la PC responde con `SOH` + contenido + `EOT`.

---

## Estado de verificación

- [x] CPU, memorias, traductor y periféricos integrados en `microcontroller.sv`.
- [x] RAM/ROM en M10K; `lw` con stall de 1 ciclo (FSM `pc_en`).
- [x] El sistema **elabora sin errores** en simulación (RTL).
- [x] **Síntesis + Fitter sin errores** en Quartus (el diseño cabe en la FPGA).
- [x] Reloj de píxel VGA de 25 MHz mediante PLL (`timer_pll`).
- [x] Suite de testbenches: RTL (sistema/periféricos), validación del stall de `lw`,
      y gate-level por módulo (CPU, VGA).
- [x] Firmware `rom.hex` cargado en la ROM.
- [x] **Asignación de pines** de la DE1-SoC en el `.qsf` (CLOCK_50, rst_n=KEY[0], PS/2, UART, VGA).
- [ ] **Demostración en hardware** (teclado PS/2 físico + monitor VGA).
