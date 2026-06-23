// ALU RV32I — 10 operaciones según ALUControl[3:0] del DISENO.md
// Genera flags zero y lt_signed para la unidad de control
module alu (
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  logic [3:0]  alu_ctrl_i,
    output logic [31:0] result_o,
    output logic        zero_o,
    output logic        lt_signed_o
);
    logic [31:0] res;

    always_comb begin
        case (alu_ctrl_i)
            4'b0000: res = a_i + b_i;                                   // ADD
            4'b0001: res = a_i - b_i;                                   // SUB
            4'b0010: res = a_i & b_i;                                   // AND
            4'b0011: res = a_i | b_i;                                   // OR
            4'b0100: res = a_i ^ b_i;                                   // XOR
            4'b0101: res = a_i << b_i[4:0];                             // SLL
            4'b0110: res = a_i >> b_i[4:0];                             // SRL
            4'b0111: res = $signed(a_i) >>> b_i[4:0];                  // SRA
            4'b1000: res = ($signed(a_i) < $signed(b_i)) ? 32'd1 : 32'd0; // SLT
            4'b1001: res = (a_i < b_i)                 ? 32'd1 : 32'd0; // SLTU
            default: res = 32'd0;
        endcase
    end

    assign result_o    = res;
    assign zero_o      = (res == 32'd0);
    assign lt_signed_o = $signed(a_i) < $signed(b_i);
endmodule
