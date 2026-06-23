// Banco de registros RV32I — 32 registros de 32 bits
// x0 siempre retorna 0; escritura síncrona, lectura asíncrona
module register_file (
    input  logic        clk_i,
    input  logic        we_i,
    input  logic [4:0]  rs1_i,
    input  logic [4:0]  rs2_i,
    input  logic [4:0]  rd_i,
    input  logic [31:0] wd_i,
    output logic [31:0] rd1_o,
    output logic [31:0] rd2_o
);
    logic [31:0] regs [31:0];

    // Lectura asíncrona — x0 siempre cero
    assign rd1_o = (rs1_i == 5'd0) ? 32'd0 : regs[rs1_i];
    assign rd2_o = (rs2_i == 5'd0) ? 32'd0 : regs[rs2_i];

    // Escritura síncrona — nunca escribe en x0
    always_ff @(posedge clk_i) begin
        if (we_i && rd_i != 5'd0)
            regs[rd_i] <= wd_i;
    end
endmodule
