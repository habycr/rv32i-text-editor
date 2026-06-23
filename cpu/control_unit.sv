// Unidad de control combinacional — CPU monociclo RV32I
// No tiene estado interno (CPI=1); todas las salidas se generan en el mismo ciclo.
// Estructura interna según DISENO.md sección 3.3–3.5:
//   1. type_decoder       — identifica formato de instrucción
//   2. ctrl_signals_gen   — genera señales generales del datapath
//   3. imm_src_gen        — selecciona formato de inmediato
//   4. alu_ctrl_gen       — selecciona operación de la ALU
//   5. branch_pc_logic    — evalúa condición de branch y selecciona próximo PC

module control_unit (
    // --- Campos de la instrucción ---
    input  logic [6:0] opcode_i,
    input  logic [2:0] funct3_i,
    input  logic [6:0] funct7_i,

    // --- Banderas de la ALU ---
    input  logic       alu_zero_i,
    input  logic       alu_lt_signed_i,

    // --- Señales de control al datapath ---
    output logic        reg_write_o,
    output logic        alu_src_o,
    output logic [1:0]  result_src_o,
    output logic        mem_read_o,
    output logic        mem_write_o,
    output logic [3:0]  alu_ctrl_o,
    output logic [2:0]  imm_src_o,
    output logic [1:0]  pc_next_src_o,

    // Selector del operando A de la ALU:
    // 00 = rs1 normal
    // 01 = zero, usado por lui
    // 10 = PC, usado por auipc
    output logic [1:0]  alu_op_a_src_o
);

    // =========================================================================
    // 1. type_decoder — decodifica el opcode a señales de tipo internas
    // =========================================================================
    logic type_R, type_I_arith, type_I_load, type_I_jalr;
    logic type_S, type_B, type_J, type_U;
    logic is_lui, is_auipc;

    always_comb begin
        type_R       = (opcode_i == 7'b0110011);
        type_I_arith = (opcode_i == 7'b0010011);
        type_I_load  = (opcode_i == 7'b0000011);
        type_I_jalr  = (opcode_i == 7'b1100111);
        type_S       = (opcode_i == 7'b0100011);
        type_B       = (opcode_i == 7'b1100011);
        type_J       = (opcode_i == 7'b1101111);

        is_lui       = (opcode_i == 7'b0110111);
        is_auipc     = (opcode_i == 7'b0010111);
        type_U       = is_lui || is_auipc;
    end

    // =========================================================================
    // 2. ctrl_signals_gen — señales generales del datapath
    // =========================================================================
    logic branch_internal, jump_internal;

    always_comb begin
        // Defaults: no hacer nada
        reg_write_o      = 1'b0;
        alu_src_o        = 1'b0;
        result_src_o     = 2'b00;
        mem_read_o       = 1'b0;
        mem_write_o      = 1'b0;
        alu_op_a_src_o   = 2'b00;   // por defecto A = rs1
        branch_internal  = 1'b0;
        jump_internal    = 1'b0;

        unique casez (1'b1)
            // R-type: add sub and or xor sll srl sra slt sltu
            type_R: begin
                reg_write_o  = 1'b1;
                alu_src_o    = 1'b0;
                result_src_o = 2'b00;
            end

            // I-type aritmético: addi andi ori xori slli srli srai slti sltiu
            type_I_arith: begin
                reg_write_o  = 1'b1;
                alu_src_o    = 1'b1;
                result_src_o = 2'b00;
            end

            // I-type load: lw
            type_I_load: begin
                reg_write_o  = 1'b1;
                alu_src_o    = 1'b1;
                result_src_o = 2'b01;
                mem_read_o   = 1'b1;
            end

            // I-type jalr
            type_I_jalr: begin
                reg_write_o   = 1'b1;
                alu_src_o     = 1'b1;
                result_src_o  = 2'b10;
                jump_internal = 1'b1;
            end

            // S-type: sw
            type_S: begin
                alu_src_o   = 1'b1;
                mem_write_o = 1'b1;
            end

            // B-type: beq bne blt bge
            type_B: begin
                alu_src_o       = 1'b0;
                branch_internal = 1'b1;
            end

            // J-type: jal
            type_J: begin
                reg_write_o   = 1'b1;
                alu_src_o     = 1'b1;
                result_src_o  = 2'b10;
                jump_internal = 1'b1;
            end

            // U-type: lui / auipc
            type_U: begin
                reg_write_o  = 1'b1;
                alu_src_o    = 1'b1;
                result_src_o = 2'b00;
            end

            default: begin /* NOP */ end
        endcase

        // Corrección importante para U-type:
        // lui   -> rd = 0 + imm_U
        // auipc -> rd = PC + imm_U
        if (is_lui) begin
            alu_op_a_src_o = 2'b01;   // A = zero
        end else if (is_auipc) begin
            alu_op_a_src_o = 2'b10;   // A = PC
        end
    end

    // =========================================================================
    // 3. imm_src_gen — selecciona el esquema de extensión de inmediato
    //    ImmSrc: 000=I  001=S  010=B  011=J  100=U
    // =========================================================================
    always_comb begin
        unique casez (1'b1)
            type_I_arith,
            type_I_load,
            type_I_jalr: imm_src_o = 3'b000;  // I-type

            type_S:       imm_src_o = 3'b001;  // S-type

            type_B:       imm_src_o = 3'b010;  // B-type

            type_J:       imm_src_o = 3'b011;  // J-type

            type_U:       imm_src_o = 3'b100;  // U-type

            default:      imm_src_o = 3'b000;
        endcase
    end

    // =========================================================================
    // 4. alu_ctrl_gen — selecciona operación de la ALU
    // =========================================================================
    always_comb begin
        alu_ctrl_o = 4'b0000; // ADD por defecto

        if (type_R || type_I_arith) begin
            case (funct3_i)
                3'b000: begin
                    if (type_R && funct7_i[5])
                        alu_ctrl_o = 4'b0001; // SUB
                    else
                        alu_ctrl_o = 4'b0000; // ADD / ADDI
                end
                3'b001: alu_ctrl_o = 4'b0101; // SLL / SLLI
                3'b010: alu_ctrl_o = 4'b1000; // SLT / SLTI
                3'b011: alu_ctrl_o = 4'b1001; // SLTU / SLTIU
                3'b100: alu_ctrl_o = 4'b0100; // XOR / XORI
                3'b101: begin
                    if (funct7_i[5])
                        alu_ctrl_o = 4'b0111; // SRA / SRAI
                    else
                        alu_ctrl_o = 4'b0110; // SRL / SRLI
                end
                3'b110: alu_ctrl_o = 4'b0011; // OR / ORI
                3'b111: alu_ctrl_o = 4'b0010; // AND / ANDI
                default: alu_ctrl_o = 4'b0000;
            endcase
        end else if (type_B) begin
            alu_ctrl_o = 4'b0001; // SUB para branches
        end
    end

    // =========================================================================
    // 5. branch_pc_logic — evalúa condición de branch y selecciona próximo PC
    // =========================================================================
    logic branch_taken;

    always_comb begin
        branch_taken = 1'b0;

        if (branch_internal) begin
            case (funct3_i)
                3'b000: branch_taken = alu_zero_i;          // beq
                3'b001: branch_taken = ~alu_zero_i;         // bne
                3'b100: branch_taken = alu_lt_signed_i;     // blt
                3'b101: branch_taken = ~alu_lt_signed_i;    // bge
                default: branch_taken = 1'b0;
            endcase
        end
    end

    always_comb begin
        if (jump_internal && type_J)
            pc_next_src_o = 2'b10;      // jal: PC + imm_J
        else if (jump_internal && type_I_jalr)
            pc_next_src_o = 2'b11;      // jalr: rs1 + imm_I
        else if (branch_taken)
            pc_next_src_o = 2'b01;      // branch tomado
        else
            pc_next_src_o = 2'b00;      // PC + 4
    end

endmodule