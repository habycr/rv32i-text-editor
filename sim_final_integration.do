# =============================================================================
# sim_final_integration.do
# -----------------------------------------------------------------------------
# Script de ModelSim/Questa para correr la integración final del microcontrolador.
#
# La idea es limpiar la librería de trabajo, compilar todos los bloques del
# proyecto con +define+SIMULATION y luego ejecutar tb_microcontroller_final.
# Ese define permite usar modelos/bypasses de simulación donde el hardware real
# usaría componentes generados por Quartus, como el PLL.
# =============================================================================

# Elimina una compilación anterior para evitar mezclar módulos viejos con los nuevos.
if {[file exists rtl_work]} {
    vdel -lib rtl_work -all
}

# Crea y mapea la librería de trabajo donde ModelSim va a compilar los módulos.
vlib rtl_work
vmap work rtl_work


# Copiar font_rom.hex a la raíz para que font_rom.sv no falle con $readmemh("font_rom.hex").
if {[file exists "rtl/peripherals/vga/font_rom.hex"]} {
    file copy -force "rtl/peripherals/vga/font_rom.hex" "font_rom.hex"
}

puts "============================================================"
puts "Compilando fuentes con +define+SIMULATION"
puts "============================================================"

# Address Translator: separa el mapa de memoria entre RAM y periféricos.
vlog -sv +define+SIMULATION "Address Translator/address_splitter.sv"
vlog -sv +define+SIMULATION "Address Translator/ram_decoder.sv"
vlog -sv +define+SIMULATION "Address Translator/peripheral_predecoder.sv"
vlog -sv +define+SIMULATION "Address Translator/peripheral_decoder.sv"
vlog -sv +define+SIMULATION "Address Translator/local_address_mux.sv"
vlog -sv +define+SIMULATION "Address Translator/address_translator.sv"

# CPU RV32I: ALU, registros, PC, extensión de inmediatos, control y datapath.
vlog -sv +define+SIMULATION "cpu/alu.sv"
vlog -sv +define+SIMULATION "cpu/register_file.sv"
vlog -sv +define+SIMULATION "cpu/program_counter.sv"
vlog -sv +define+SIMULATION "cpu/sign_extend.sv"
vlog -sv +define+SIMULATION "cpu/control_unit.sv"
vlog -sv +define+SIMULATION "cpu/riscv_datapath.sv"
vlog -sv +define+SIMULATION "cpu/riscv_cpu.sv"

# Memorias base del sistema: ROM de programa y RAM de datos.
vlog -sv +define+SIMULATION "rtl/peripherals/rom/rom.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/ram/ram.sv"

# UART: generador de baudrate, transmisor, receptor y wrapper mapeado a memoria.
vlog -sv +define+SIMULATION "rtl/peripherals/uart/baud_gen.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/uart/uart_tx.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/uart/uart_rx.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/uart/uart_peripheral.sv"

# PS/2: sincronización, recepción de frames, FSM, transmisión y periférico final.
vlog -sv +define+SIMULATION "rtl/peripherals/ps2/ps2_sync.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/ps2/ps2_parity_chk.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/ps2/ps2_rx_frame.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/ps2/ps2_rx_fsm.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/ps2/ps2_tx.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/ps2/ps2_peripheral.sv"

# Timer: prescaler, contador, periférico y wrapper del PLL usado por el top.
vlog -sv +define+SIMULATION "rtl/peripherals/timer/timer_prescaler.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/timer/timer_counter.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/timer/timer_peripheral.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/timer/timer_pll_wrapper.sv"

# VGA de texto: paleta, ROM de fuente, buffer, timing, clock y controlador.
vlog -sv +define+SIMULATION "rtl/peripherals/vga/cga_palette.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/vga/font_rom.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/vga/text_buffer.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/vga/vga_timing_gen.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/vga/vga_clk_gen.sv"
vlog -sv +define+SIMULATION "rtl/peripherals/vga/vga_controller.sv"

# Top del sistema y testbench integral final.
vlog -sv +define+SIMULATION "microcontroller.sv"
vlog -sv +define+SIMULATION "tb/tb_microcontroller_final.sv"

puts "============================================================"
puts "Simulando testbench final"
puts "============================================================"

# Testbench integral v5: PS/2 + VGA + stall lw + :q + :w + :r.
# Los parámetros ENABLE_* se dejan por compatibilidad con versiones anteriores del TB.
vsim -voptargs=+acc work.tb_microcontroller_final \
    -GROM_FILE="rom.hex" \
    -GENABLE_BACKSPACE_TEST=1 \
    -GENABLE_COMMAND_Q_TEST=1 \
    -GENABLE_UART_SAVE_TEST=1 \
    -GDEBUG_VGA=0 \
    -GDEBUG_PS2=0 \
    -GDEBUG_BUS=0 \
    -GDEBUG_STALL=0 \
    -GDEBUG_UART=0

# Ejecuta el testbench completo hasta que este termine por sí mismo.
run -all
