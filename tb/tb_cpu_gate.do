# ============================================================================
# tb_cpu_gate.do  --  Corre la simulacion del testbench de la CPU (riscv_cpu)
# Proyecto CE 3201 — DE1-SoC (Cyclone V)
#
# USO (desde la RAIZ del proyecto, en la consola de ModelSim):
#     do tb/tb_cpu_gate.do
#
# Detecta automaticamente el modo:
#   * Si existe simulation/modelsim/riscv_cpu.svo  -> GATE-LEVEL
#       - con riscv_cpu_v.sdo  -> gate-level CON timing (SDF)
#       - sin el .sdo          -> gate-level funcional (sin timing)
#   * Si NO existe el netlist   -> simulacion RTL (fuentes cpu/*.sv)
#
# Para generar el netlist gate-level (una vez, en Quartus):
#   Settings -> General -> Top-Level Entity = riscv_cpu, compilar (Ctrl+L).
#   Genera simulation/modelsim/riscv_cpu.svo y riscv_cpu_v.sdo
#   Luego restaurar microcontroller como Top-Level Entity.
# ============================================================================

quietly set NETLIST simulation/modelsim/riscv_cpu.svo
quietly set SDF     simulation/modelsim/riscv_cpu_v.sdo

# --- Librería de trabajo limpia ---
if {[file isdirectory work]} { catch {vdel -all} }
vlib work

# --- Compilar DUT (netlist gate-level o fuentes RTL) ---
if {[file exists $NETLIST]} {
    echo "### Modo GATE-LEVEL: compilando $NETLIST"
    vlog -sv $NETLIST
} else {
    echo "### Modo RTL (no hay netlist gate-level): compilando cpu/*.sv"
    vlog -sv cpu/sign_extend.sv cpu/alu.sv cpu/register_file.sv \
             cpu/program_counter.sv cpu/control_unit.sv \
             cpu/riscv_datapath.sv cpu/riscv_cpu.sv
}

# --- Compilar el testbench ---
vlog -sv tb/tb_cpu_gate.sv

# --- Lanzar la simulacion ---
if {[file exists $NETLIST] && [file exists $SDF]} {
    echo "### Anotando SDF: $SDF"
    vsim -t ps -L cyclonev_ver -L altera_ver -L altera_mf_ver \
               -L altera_lnsim_ver -L lpm_ver -L sgate_ver \
         -sdftyp /tb_cpu_gate/u_dut=$SDF tb_cpu_gate
} elseif {[file exists $NETLIST]} {
    echo "### Gate-level SIN SDF (netlist funcional, sin timing)"
    vsim -t ps -L cyclonev_ver -L altera_ver -L altera_mf_ver \
               -L altera_lnsim_ver -L lpm_ver -L sgate_ver tb_cpu_gate
} else {
    echo "### Simulacion RTL funcional"
    vsim -t ps tb_cpu_gate
}

# (opcional) ver señales en el visor de ondas:
# add wave -r /*

run -all
