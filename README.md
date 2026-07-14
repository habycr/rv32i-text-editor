# RV32I Microcontroller and VGA Text Editor

> A 32-bit RISC-V microcontroller implemented in SystemVerilog that runs an interactive text editor on an Intel Cyclone V FPGA.

This project was developed collaboratively for **CE 3201 — Taller de Diseño Digital** at the **Instituto Tecnológico de Costa Rica** during the first semester of 2026.

The system implements a small computer from the processor up. Its firmware is written in RV32I assembly, text is entered with a PS/2 keyboard, the document is displayed on a VGA monitor, and files can be transferred to or from a PC through UART.

This README provides a practical overview of the system, its operation, firmware, build process, and verification. Detailed hardware design, module interfaces, control logic, instruction tables, and engineering diagrams are documented separately in [`DISENO.md`](DISENO.md).

## Table of Contents

- [What the System Does](#what-the-system-does)
- [How It Works](#how-it-works)
- [Main Features](#main-features)
- [CPU](#cpu)
- [Memory Map](#memory-map)
- [Peripherals](#peripherals)
- [Text Editor](#text-editor)
- [UART File Transfer](#uart-file-transfer)
- [Repository Structure](#repository-structure)
- [Requirements](#requirements)
- [Build the Firmware](#build-the-firmware)
- [Synthesize and Program the FPGA](#synthesize-and-program-the-fpga)
- [Simulation and Verification](#simulation-and-verification)
- [Known Limitations](#known-limitations)
- [Development Team](#development-team)
- [Project Origin](#project-origin)
- [Project Status](#project-status)

## What the System Does

The project combines hardware and software into one FPGA-based system:

- The **RV32I CPU** executes the editor firmware.
- A **PS/2 keyboard controller** receives keystrokes.
- A **VGA text controller** displays an 80 × 24 character terminal.
- A **timer** provides delays and cursor timing.
- A **UART controller** transfers text between the FPGA and a PC.
- Program and data memories are implemented with the FPGA's internal **M10K memory blocks**.

The user can type and edit text directly on the FPGA without an operating system or external processor.

## How It Works

1. After reset, the CPU begins executing instructions from address `0x0000_0000`.
2. The program ROM supplies the RV32I firmware instruction selected by the program counter.
3. When the firmware accesses data, the address translator selects RAM or one of the peripherals.
4. Keyboard events are read from the PS/2 controller and converted into editor actions.
5. The firmware writes characters and cursor information into the VGA text buffer.
6. The VGA controller converts that buffer into a 640 × 480 video signal.
7. Save and load commands exchange the document with a PC through UART.

The firmware uses polling rather than interrupts, which keeps the CPU and peripheral interface simple.

## Main Features

- 32-bit processor based on the **RISC-V RV32I** base integer architecture.
- Separate instruction and data buses.
- Program ROM: **8 KB**.
- Data RAM: **4 KB**.
- Memory-mapped UART, PS/2, timer, VGA control registers, and VGA text buffer.
- UART communication at **115200 baud, 8N1**.
- PS/2 keyboard support using **Scancode Set 2**.
- VGA output at **640 × 480, 60 Hz**.
- Text display with **80 columns × 24 rows**.
- 25 MHz VGA pixel clock generated from the 50 MHz board clock with a PLL.
- Interactive editor firmware written in RV32I assembly.
- RTL and module-level verification with self-checking testbenches.
- Quartus project configured for the **DE1-SoC** board and Cyclone V device `5CSEMA5F31C6`.

## CPU

The processor uses a 32-bit datapath with:

- program counter;
- 32 × 32-bit register file;
- combinational ALU;
- immediate generator;
- combinational control unit;
- next-PC and result-selection multiplexers.

### Implemented instructions

```text
lw, sw,
sll, slli, srl, srli, sra, srai,
add, sub, and, or, xor,
addi, andi, ori, xori,
beq, bne, blt, bge,
slt, slti, sltu, sltiu,
jal, jalr
```

Most instructions complete in one clock cycle.

`lw` requires two cycles because the M10K data RAM has synchronous read latency. A two-state control sequence temporarily holds the program counter and delays register write-back until the RAM output is valid:

```text
ST_IDLE → ST_LOAD_WAIT → ST_IDLE
```

This keeps the rest of the datapath simple while allowing the data memory to remain implemented with dedicated FPGA memory blocks.

## Memory Map

### Main regions

| Region | Address range | Size | Purpose |
|---|---:|---:|---|
| Program ROM | `0x0000_0000` – `0x0000_1FFF` | 8 KB | RV32I editor firmware |
| Data RAM | `0x0000_2000` – `0x0000_2FFF` | 4 KB | Stack, variables, and temporary data |
| Peripherals | `0x0001_0000` – `0x0001_FFFF` | 64 KB window | Control, status, and data registers |

### Peripheral addresses

| Peripheral | Address |
|---|---:|
| UART control/status | `0x0001_0040` |
| UART TX data | `0x0001_0044` |
| UART RX data | `0x0001_0048` |
| PS/2 control/status | `0x0001_0050` |
| PS/2 RX data | `0x0001_0054` |
| PS/2 TX data | `0x0001_0058` |
| Timer control/status | `0x0001_0060` |
| Timer data | `0x0001_0064` |
| VGA control/cursor | `0x0001_0120` |
| VGA text buffer | `0x0001_1000` – `0x0001_2DFF` |

## Peripherals

### UART

The UART peripheral provides transmit, receive, control, and status registers. It operates at 115200 baud with 8 data bits, no parity, and one stop bit.

### PS/2

The PS/2 peripheral synchronizes the external clock and data signals, receives 11-bit frames, checks odd parity, and handles Set 2 make, break, and extended-key prefixes.

### Timer

The timer contains a prescaler and 32-bit counter. The firmware uses it for timing operations such as cursor behavior.

### VGA

The VGA subsystem contains:

- timing generator;
- dual-clock text buffer;
- font ROM;
- CGA-style color palette;
- cursor and control registers;
- pixel-clock generation.

Each screen cell stores the information required to render one text character.

## Text Editor

The firmware provides two operating modes inspired by `vim`.

### Insert mode

- Type printable characters.
- Move with the arrow keys.
- Use `Enter` for a new line.
- Use `Backspace` to remove the previous character.
- Press `Esc` to enter command mode.

### Command mode

| Command | Action |
|---|---|
| `i` | Return to insert mode |
| `:w` | Send the current document to the PC |
| `:r` | Request and load a document from the PC |
| `:q` | Clear the text buffer |
| Arrow keys | Move the cursor |

## UART File Transfer

The editor uses a small byte-oriented protocol.

### Save: FPGA to PC

```text
SOH (0x01) → file contents → EOT (0x04)
```

### Load: PC to FPGA

```text
FPGA sends ENQ (0x05)
PC responds with SOH (0x01) → file contents → EOT (0x04)
```

A serial terminal or a Python program can be used on the PC side.

## Repository Structure

```text
.
├── microcontroller.sv          # Complete system top level
├── microcontroller.qpf         # Quartus project
├── microcontroller.qsf         # Device, source, and pin assignments
├── microcontroller.sdc         # Timing constraints
├── rom.hex                     # Firmware image loaded by the program ROM
├── cpu/                        # RV32I CPU and datapath
├── Address Translator/         # Address decoding and local-address generation
├── rtl/
│   ├── firmware/               # Assembly editor and ROM build script
│   └── peripherals/
│       ├── rom/
│       ├── ram/
│       ├── uart/
│       ├── ps2/
│       ├── timer/
│       └── vga/
├── tb/                         # RTL, integration, stall, and peripheral testbenches
├── timer_pll/                  # Quartus PLL IP for the 25 MHz VGA clock
├── DISENO.md                   # Detailed engineering design document
├── PATCH_NOTES.md              # M10K RAM and lw-stall design notes
└── README.md
```

Generated Quartus and ModelSim build directories should not be committed.

## Requirements

### Software

- Intel Quartus Prime Lite 18.0.
- ModelSim — Intel FPGA Edition or a compatible QuestaSim installation.
- Python 3.6 or newer.
- A RISC-V GNU embedded toolchain providing:
  - `riscv32-unknown-elf-*`, or
  - `riscv64-unknown-elf-*`.

### Hardware

- DE1-SoC development board.
- PS/2 keyboard.
- VGA monitor and cable.
- USB-to-UART adapter or compatible serial connection for file transfer.

## Build the Firmware

From the repository root:

```bash
cd rtl/firmware
python build_rom.py editor.s
```

The script:

1. assembles the source for `rv32i`;
2. links it at address `0x0000_0000`;
3. creates a disassembly file;
4. checks for unsupported instructions;
5. generates a 2048-word `rom.hex` image padded with RV32I NOP instructions.

Copy the resulting ROM image to the repository root.

### Linux or macOS

```bash
cp rom.hex ../../rom.hex
```

### Windows PowerShell

```powershell
Copy-Item .\rom.hex ..\..\rom.hex -Force
```

## Synthesize and Program the FPGA

1. Open `microcontroller.qpf` in Quartus Prime Lite 18.0.
2. Confirm that `microcontroller.sv` is configured as the top-level entity.
3. Confirm that `rom.hex`, the PLL IP, and all SystemVerilog sources are available.
4. Run **Processing → Start Compilation**.
5. Open **Tools → Programmer**.
6. Select the generated `.sof` file.
7. Program the DE1-SoC.

The `.qsf` contains the assignments for the board clock, reset, PS/2, UART, and VGA ports.

## Simulation and Verification

Verification is organized in layers.

| Level | Main files | Purpose |
|---|---|---|
| Complete RTL system | `tb/tb_microcontroller_final.sv`, `tb/tb_microcontroller_full_compact.sv` | CPU, memories, bus, and peripherals together |
| UART | `tb/tb_uart_peripheral.sv` | Transmit and receive behavior |
| PS/2 | `tb/tb_ps2_peripheral.sv` | Frame reception, prefixes, and keyboard data |
| Timer | `tb/timer/tb_timer_peripheral.sv` | Prescaler, counting, and register interface |
| `lw` stall | `tb/sim_validacion_stall/` | Synchronous RAM latency and dependent instructions |
| Gate level | `tb/tb_cpu_gate.sv`, `tb/tb_vga_gate.sv` | Post-synthesis CPU and VGA checks |

For RTL simulation of the complete system, compile with:

```text
+define+SIMULATION
```

This selects the simulation model in `timer_pll_wrapper`. The real 25 MHz pixel clock is generated by the Quartus PLL in hardware.

The full design document contains the module interfaces and verification strategy:

- [`DISENO.md`](DISENO.md)


## Known Limitations

- The implemented CPU supports only the RV32I instructions required by the editor.
- Byte and halfword load/store instructions are not implemented.
- The CPU does not implement interrupts; firmware communicates with peripherals through polling.
- `lw` takes two cycles because of synchronous M10K RAM latency.
- The editor is limited to the fixed VGA text-buffer capacity.
- UART transfer uses a simple framing protocol without error correction or retransmission.
- A complete gate-level simulation may require a full ModelSim or QuestaSim installation because Cyclone V PLL models can be encrypted or restricted in the Starter Edition.
- The final physical demonstration with a PS/2 keyboard and VGA monitor remains pending.

## Development Team

Developed collaboratively by:

- José García Izaguirre
- Dylan Maximiliano Guerrero González
- Antony Javier Hernández Castillo

**Course:** CE 3201 — Taller de Diseño Digital  
**Institution:** Instituto Tecnológico de Costa Rica  

## Project Origin

This repository is a public portfolio copy of a collaborative academic project originally developed in a private GitLab repository.

The original commit history and authorship were preserved when the project was moved to GitHub.

## Project Status

**Completed academic FPGA implementation.**

The CPU, memories, address translator, peripherals, firmware image, timing constraints, and FPGA pin assignments are integrated. RTL simulation and Quartus synthesis/Fitter completed successfully.

The remaining validation step is the complete physical demonstration using the DE1-SoC board, PS/2 keyboard, VGA monitor, and UART connection.
