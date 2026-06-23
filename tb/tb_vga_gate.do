# ============================================================================
# tb_vga_gate.do  --  Corre la simulacion del testbench del VGA (vga_controller)
# Proyecto CE 3201 — DE1-SoC (Cyclone V)
#
# USO (desde la RAIZ del proyecto, en la consola de ModelSim):
#     do tb/tb_vga_gate.do
#
# Detecta automaticamente el modo:
#   * Si existe simulation/modelsim/vga_controller.svo -> GATE-LEVEL
#       - con vga_controller_v.sdo -> gate-level CON timing (SDF)
#       - sin el .sdo              -> gate-level funcional (sin timing)
#   * Si NO existe el netlist       -> simulacion RTL (fuentes vga/*.sv)
#
# Para generar el netlist gate-level (una vez, en Quartus):
#   Settings -> General -> Top-Level Entity = vga_controller, compilar (Ctrl+L).
#   Genera simulation/modelsim/vga_controller.svo y vga_controller_v.sdo
#   Luego restaurar microcontroller como Top-Level Entity.
#
# NOTA: el TB recorre un cuadro completo (~16 ms simulados) para capturar vsync;
#       la corrida tarda. Y necesita font_rom.hex en la raiz (ya esta ahi).
# ============================================================================

quietly set NETLIST simulation/modelsim/vga_controller.svo
quietly set SDF     simulation/modelsim/vga_controller_v.sdo

# --- Librería de trabajo limpia ---
if {[file isdirectory work]} { catch {vdel -all} }
vlib work

# --- Compilar DUT (netlist gate-level o fuentes RTL) ---
if {[file exists $NETLIST]} {
    echo "### Modo GATE-LEVEL: compilando $NETLIST"
    vlog -sv $NETLIST
} else {
    echo "### Modo RTL (no hay netlist gate-level): compilando rtl/peripherals/vga/*.sv"
    # +define+SIMULATION hace que text_buffer use su modelo de memoria de
    # comportamiento (evita necesitar la libreria altera_mf en modo RTL).
    vlog -sv +define+SIMULATION \
             rtl/peripherals/vga/vga_timing_gen.sv \
             rtl/peripherals/vga/text_buffer.sv \
             rtl/peripherals/vga/font_rom.sv \
             rtl/peripherals/vga/cga_palette.sv \
             rtl/peripherals/vga/vga_controller.sv
}

# --- Compilar el testbench ---
vlog -sv tb/tb_vga_gate.sv

# --- Lanzar la simulacion ---
if {[file exists $NETLIST] && [file exists $SDF]} {
    echo "### Anotando SDF: $SDF"
    vsim -t ps -L cyclonev_ver -L altera_ver -L altera_mf_ver \
               -L altera_lnsim_ver -L lpm_ver -L sgate_ver \
         -sdftyp /tb_vga_gate/u_dut=$SDF tb_vga_gate
} elseif {[file exists $NETLIST]} {
    echo "### Gate-level SIN SDF (netlist funcional, sin timing)"
    vsim -t ps -L cyclonev_ver -L altera_ver -L altera_mf_ver \
               -L altera_lnsim_ver -L lpm_ver -L sgate_ver tb_vga_gate
} else {
    echo "### Simulacion RTL funcional"
    vsim -t ps tb_vga_gate
}

# (opcional) ver las señales VGA en el visor de ondas:
# add wave /tb_vga_gate/hsync /tb_vga_gate/vsync /tb_vga_gate/r /tb_vga_gate/g /tb_vga_gate/b

run -all
