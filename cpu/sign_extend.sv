// Extensión de signo — construye el inmediato de 32 bits según ImmSrc[2:0]
// ImmSrc: 000=I, 001=S, 010=B, 011=J, 100=U
module sign_extend (
    input  logic [31:0] instr_i,    // instrucción completa
    input  logic [2:0]  imm_src_i,
    output logic [31:0] imm_ext_o
);
    always_comb begin
        case (imm_src_i)
            // I-type: bits [31:20]
            3'b000: imm_ext_o = {{20{instr_i[31]}}, instr_i[31:20]};

            // S-type: bits [31:25] y [11:7]
            3'b001: imm_ext_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};

            // B-type: bits [31], [7], [30:25], [11:8] — desplazado 1 bit
            3'b010: imm_ext_o = {{20{instr_i[31]}},
                                   instr_i[7],
                                   instr_i[30:25],
                                   instr_i[11:8],
                                   1'b0};

            // J-type: bits [31], [19:12], [20], [30:21] — desplazado 1 bit
            3'b011: imm_ext_o = {{12{instr_i[31]}},
                                   instr_i[19:12],
                                   instr_i[20],
                                   instr_i[30:21],
                                   1'b0};

            // U-type: bits [31:12] en posición alta
            3'b100: imm_ext_o = {instr_i[31:12], 12'b0};

            default: imm_ext_o = 32'd0;
        endcase
    end
endmodule
