`timescale 1ns/1ps

module tb_lw_stall2;

    logic clk = 0;
    logic rst_n = 0;
    always #10 clk = ~clk;

    logic [31:0] prog_addr, prog_in;
    logic [31:0] data_addr, data_out, data_in;
    logic        we;

    riscv_cpu u_cpu (
        .clk_i(clk), .rst_i(rst_n),
        .prog_addr_o(prog_addr), .prog_in_i(prog_in),
        .data_addr_o(data_addr), .data_out_o(data_out),
        .data_in_i(data_in), .we_o(we)
    );

    rom #(.INIT_FILE("rom_init2.hex")) u_rom (
        .clk(clk), .ProgAddress_o(prog_addr), .ProgIn_i(prog_in)
    );

    ram u_ram (
        .clk(clk), .local_addr_o(data_addr[12:0]), .we_o(we),
        .cs_ram_o(1'b1), .DataOut_o(data_out), .ram_data_o(data_in)
    );

    integer cycle;
    initial cycle = 0;
    always @(posedge clk) begin
        if (rst_n) begin
            cycle <= cycle + 1;
            $display("cyc=%0d pc=0x%0h instr=0x%08h we=%0b state=%0d t2(x7)=0x%0h t3(x8)=0x%0h t4(x9)=0x%0h t5(x10)=0x%0h t6(x12)=0x%0h x11=0x%0h",
                cycle, prog_addr, prog_in, we, u_cpu.state_q,
                u_cpu.u_dp.u_regfile.regs[7], u_cpu.u_dp.u_regfile.regs[8],
                u_cpu.u_dp.u_regfile.regs[9], u_cpu.u_dp.u_regfile.regs[10],
                u_cpu.u_dp.u_regfile.regs[12], u_cpu.u_dp.u_regfile.regs[11]);
        end
    end

    initial begin
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (35) @(posedge clk);

        $display("=== Resultado ===");
        $display("t2(x7)=0x%0h (esperado 0xaa)", u_cpu.u_dp.u_regfile.regs[7]);
        $display("t3(x8)=0x%0h (esperado 0xbb)", u_cpu.u_dp.u_regfile.regs[8]);
        $display("t4(x9)=0x%0h (esperado 0x999, branch1 NO tomado)", u_cpu.u_dp.u_regfile.regs[9]);
        $display("t5(x10)=0x%0h (esperado 0xaa)", u_cpu.u_dp.u_regfile.regs[10]);
        $display("x11=0x%0h (esperado 0x0 - NUNCA debe ejecutarse, branch2 tomado)", u_cpu.u_dp.u_regfile.regs[11]);
        $display("t6(x12)=0x%0h (esperado 0x222, confirma que branch2 SI salto a 0x40)", u_cpu.u_dp.u_regfile.regs[12]);

        if (u_cpu.u_dp.u_regfile.regs[7] === 32'haa && u_cpu.u_dp.u_regfile.regs[8] === 32'hbb &&
            u_cpu.u_dp.u_regfile.regs[9] === 32'h999 && u_cpu.u_dp.u_regfile.regs[10] === 32'haa &&
            u_cpu.u_dp.u_regfile.regs[11] === 32'h0 && u_cpu.u_dp.u_regfile.regs[12] === 32'h222)
            $display(">>> TODO CORRECTO <<<");
        else
            $display(">>> FALLO EN ALGUNA VERIFICACION <<<");

        $finish;
    end
endmodule
