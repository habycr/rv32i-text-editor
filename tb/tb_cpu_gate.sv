`timescale 1ns/1ps
// ============================================================================
// tb_cpu_gate.sv  --  Testbench GATE-LEVEL para la CPU RISC-V (riscv_cpu)
// Proyecto CE 3201 — DE1-SoC (Cyclone V 5CSEMA5F31C6)
//
// QUÉ ES UN TESTBENCH GATE-LEVEL
//   A diferencia de la simulación RTL (que usa los .sv fuente), aquí la CPU es
//   el NETLIST POST-SÍNTESIS (compuertas + primitivas Cyclone V) con retardos
//   reales anotados desde un archivo SDF (.sdo). Sirve para verificar que el
//   diseño SIGUE FUNCIONANDO después de sintetizar y mapear, con timing real.
//
//   Como el netlist está APLANADO, este TB NO accede a señales internas
//   (regfile, PC interno, etc.) -- solo verifica por los PUERTOS de la CPU.
//   Por eso usa un programa diminuto cuyo efecto es OBSERVABLE en el bus de
//   datos (un 'sw' a una dirección y dato conocidos).
//
// CÓMO GENERAR EL NETLIST DE LA CPU (en Quartus, una sola vez)
//   1. Assignments -> Settings -> General: poner 'riscv_cpu' como Top-Level Entity.
//   2. Compilar (Ctrl+L). Quartus genera en simulation/modelsim/:
//        riscv_cpu.svo   (netlist gate-level)
//        riscv_cpu_v.sdo (retardos SDF)
//   3. Volver a poner 'microcontroller' como Top-Level Entity para el resto.
//
// CÓMO CORRER EN MODELSIM (gate-level)
//   vlib work
//   # librerías de simulación Cyclone V (ajustar ruta de Quartus si difiere):
//   vlog -work work $QUARTUS/eda/sim_lib/cyclonev_atoms.v
//   vlog -work work $QUARTUS/eda/sim_lib/altera_primitives.v
//   vlog -sv simulation/modelsim/riscv_cpu.svo
//   vlog -sv tb/tb_cpu_gate.sv
//   vsim -t ps -sdftyp u_dut=simulation/modelsim/riscv_cpu_v.sdo tb_cpu_gate
//   run -all
//
//   (El -sdftyp es la forma recomendada por ModelSim de anotar el SDF; el
//    bloque $sdf_annotate de abajo es una alternativa equivalente dentro del TB.)
// ============================================================================

module tb_cpu_gate;

    // ------------------------------------------------------------------------
    // Reloj y reset (clk_sys = 25 MHz -> periodo 40 ns, como en hardware)
    // ------------------------------------------------------------------------
    logic clk   = 1'b0;
    logic rst_n = 1'b0;
    always #20 clk = ~clk;          // 40 ns -> 25 MHz

    // ------------------------------------------------------------------------
    // Interfaz de la CPU
    // ------------------------------------------------------------------------
    logic [31:0] prog_addr;         // CPU -> ROM (dirección de instrucción)
    logic [31:0] prog_in;           // ROM -> CPU (instrucción)
    logic [31:0] data_addr;         // CPU -> bus de datos (dirección)
    logic [31:0] data_out;          // CPU -> bus de datos (dato a escribir)
    logic [31:0] data_in;           // bus de datos -> CPU (dato leído)
    logic        we;                // CPU -> bus de datos (write enable)

    // DUT: la CPU. En gate-level esta instancia ES el netlist riscv_cpu.svo.
    riscv_cpu u_dut (
        .clk_i       (clk),
        .rst_i       (rst_n),
        .prog_addr_o (prog_addr),
        .prog_in_i   (prog_in),
        .data_addr_o (data_addr),
        .data_out_o  (data_out),
        .data_in_i   (data_in),
        .we_o        (we)
    );

    // ------------------------------------------------------------------------
    // Memoria de instrucciones de prueba (modelo de comportamiento del TB).
    // Programa diminuto, efecto OBSERVABLE por puerto:
    //   0x00  addi x5, x0, 0x55     ; x5 = 0x55
    //   0x04  addi x6, x0, 0x100    ; x6 = 0x100  (dirección destino)
    //   0x08  sw   x5, 0(x6)        ; MEM[0x100] = 0x55  -> we=1 en el bus
    //   0x0C  jal  x0, 0            ; lazo infinito aquí (halt)
    // Solo usa RV32I (sin mul/lb/etc.), igual que el ISA de este CPU.
    // ------------------------------------------------------------------------
    localparam [31:0] PROG [0:3] = '{
        32'h05500293,   // addi x5, x0, 0x55
        32'h10000313,   // addi x6, x0, 0x100
        32'h00532023,   // sw   x5, 0(x6)
        32'h0000006F    // jal  x0, 0  (loop)
    };

    // Fetch combinacional: la palabra en prog_addr (alineada a 4). Direcciones
    // fuera del programa devuelven NOP (0x00000013) para que un fetch
    // especulativo no rompa la simulación.
    logic [31:0] word_idx;
    assign word_idx = prog_addr[31:2];
    assign prog_in  = (word_idx <= 32'd3) ? PROG[word_idx[1:0]] : 32'h00000013;

    // No hay 'lw' en el programa -> el bus de lectura puede quedar en 0.
    assign data_in = 32'd0;

    // ------------------------------------------------------------------------
    // Verificación por puertos: capturar el 'sw'
    // ------------------------------------------------------------------------
    localparam [31:0] EXP_ADDR = 32'h0000_0100;
    localparam [31:0] EXP_DATA = 32'h0000_0055;

    bit          store_seen;
    logic [31:0] store_addr, store_data;

    initial begin
        store_seen = 1'b0;
        store_addr = '0;
        store_data = '0;
    end

    // Muestrea en cada flanco de subida: si la CPU está ejecutando el 'sw',
    // we=1 con la dirección y el dato esperados.
    always @(posedge clk) begin
        if (rst_n && we && !store_seen) begin
            store_seen = 1'b1;
            store_addr = data_addr;
            store_data = data_out;
            $display("[%0t] STORE detectado: addr=0x%08h  data=0x%08h",
                     $time, store_addr, store_data);
        end
    end

    // ------------------------------------------------------------------------
    // (Opcional) Anotación SDF dentro del TB. Equivale a -sdftyp de vsim.
    // Descomentar si NO se usa -sdftyp en la línea de vsim. Ajustar la ruta.
    // ------------------------------------------------------------------------
    // initial begin
    //     $sdf_annotate("simulation/modelsim/riscv_cpu_v.sdo", u_dut);
    // end

    // ------------------------------------------------------------------------
    // Secuencia de prueba
    // ------------------------------------------------------------------------
    initial begin
        $display("=== tb_cpu_gate: simulacion GATE-LEVEL de riscv_cpu ===");
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        // Ciclos suficientes para ejecutar addi, addi, sw y llegar al lazo.
        repeat (20) @(posedge clk);

        // -------- Evaluación --------
        $display("--- Resultado ---");
        if (!store_seen) begin
            $display("FALLO: la CPU nunca generó un 'sw' (we nunca se activó).");
        end else if (store_addr !== EXP_ADDR) begin
            $display("FALLO: direccion de store = 0x%08h (esperado 0x%08h).",
                     store_addr, EXP_ADDR);
        end else if (store_data !== EXP_DATA) begin
            $display("FALLO: dato de store = 0x%08h (esperado 0x%08h).",
                     store_data, EXP_DATA);
        end else begin
            $display("OK: la CPU ejecuto 'sw x5,0(x6)' con addr=0x%08h data=0x%08h.",
                     store_addr, store_data);
            $display("OK: addi + sw funcionan en el netlist gate-level.");
        end

        $display("=== Fin tb_cpu_gate ===");
        $finish;
    end

    // Watchdog: evita simulación colgada.
    initial begin
        #100000;  // 100 us
        $display("FALLO: watchdog -- la simulacion no termino a tiempo.");
        $finish;
    end

endmodule
