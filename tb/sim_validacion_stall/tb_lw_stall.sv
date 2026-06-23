`timescale 1ns/1ps

module tb_lw_stall;

    logic clk = 0;
    logic rst_n = 0;

    // Reloj 50 MHz equivalente (periodo 20ns), para fidelidad con el diseño real
    always #10 clk = ~clk;

    // --- Señales CPU <-> ROM ---
    logic [31:0] prog_addr;
    logic [31:0] prog_in;

    // --- Señales CPU <-> RAM (bus de datos simplificado, sin address_translator) ---
    logic [31:0] data_addr;
    logic [31:0] data_out;
    logic [31:0] data_in;
    logic        we;

    riscv_cpu u_cpu (
        .clk_i       (clk),
        .rst_i       (rst_n),
        .prog_addr_o (prog_addr),
        .prog_in_i   (prog_in),
        .data_addr_o (data_addr),
        .data_out_o  (data_out),
        .data_in_i   (data_in),
        .we_o        (we)
    );

    rom #(
        .INIT_FILE ("rom_init.hex")
    ) u_rom (
        .clk           (clk),
        .ProgAddress_o (prog_addr),
        .ProgIn_i      (prog_in)
    );

    // RAM conectada directamente: local_addr_o = data_addr[12:0],
    // cs_ram_o amarrado en 1 (todo el espacio de datos es RAM en esta prueba).
    ram u_ram (
        .clk          (clk),
        .local_addr_o (data_addr[12:0]),
        .we_o         (we),
        .cs_ram_o     (1'b1),
        .DataOut_o    (data_out),
        .ram_data_o   (data_in)
    );

    // --- Monitor cycle-by-cycle ---
    integer cycle;
    initial cycle = 0;

    always @(posedge clk) begin
        if (rst_n) begin
            cycle <= cycle + 1;
            $display("t=%0t cyc=%0d pc=%0d(0x%0h) instr=0x%08h we=%0b data_addr=0x%0h data_out=0x%0h data_in=0x%0h state=%0d rd1[ra]=0x%0h x28=0x%0h",
                $time, cycle, prog_addr, prog_addr, prog_in, we, data_addr, data_out, data_in,
                u_cpu.state_q,
                u_cpu.u_dp.u_regfile.regs[1],
                u_cpu.u_dp.u_regfile.regs[28]
            );
        end
    end

    initial begin
        $display("=== Inicio de simulacion: stall de lw + ret ===");
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        // Suficientes ciclos para ejecutar el programa completo, incluido
        // el salto via jalr a 0x40 y la instruccion marcador ahi.
        repeat (40) @(posedge clk);

        $display("=== Estado final ===");
        $display("ra (x1)  = 0x%0h (esperado 0x40 = 64)", u_cpu.u_dp.u_regfile.regs[1]);
        $display("t3 (x28) = 0x%0h (esperado 0x3ab si el jalr salto correctamente a 0x40)", u_cpu.u_dp.u_regfile.regs[28]);

        if (u_cpu.u_dp.u_regfile.regs[1] !== 32'h40) begin
            $display("FALLO: ra no contiene el valor correcto leido de RAM (lw fallo)");
        end else begin
            $display("OK: ra contiene el valor correcto leido por lw");
        end

        if (u_cpu.u_dp.u_regfile.regs[28] !== 32'h3ab) begin
            $display("FALLO: jalr/ret no salto a la direccion correcta (x28 no se escribio)");
        end else begin
            $display("OK: jalr salto correctamente a la direccion devuelta por lw (ret funciono)");
        end

        $finish;
    end

endmodule
