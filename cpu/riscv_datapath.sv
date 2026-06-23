// Datapath monociclo RV32I
// Conecta PC, banco de registros, ALU, sign extend y MUXes.
// Incluye selector de operando A para soportar correctamente lui y auipc.

module riscv_datapath (
    input  logic        clk_i,
    input  logic        rst_i,

    // --- Interfaz de instrucciones ---
    output logic [31:0] pc_o,
    input  logic [31:0] instr_i,

    // --- Interfaz de datos ---
    output logic [31:0] data_addr_o,
    output logic [31:0] data_wdata_o,
    input  logic [31:0] data_rdata_i,
    output logic        data_we_o,

    // --- Señales de control ---
    input  logic        reg_write_i,
    input  logic        alu_src_i,
    input  logic [1:0]  result_src_i,
    input  logic        mem_write_i,
    input  logic [3:0]  alu_ctrl_i,
    input  logic [2:0]  imm_src_i,
    input  logic [1:0]  pc_next_src_i,
    input  logic [1:0]  alu_op_a_src_i, // 00=rs1, 01=zero, 10=PC

    // --- Control de stall ---
    input  logic        pc_en_i,

    // --- Banderas hacia control_unit ---
    output logic        alu_zero_o,
    output logic        alu_lt_signed_o
);

    // --- Señales internas ---
    logic [31:0] pc, pc_plus4, pc_next;
    logic [31:0] instr;
    logic [31:0] rs1_data, rs2_data;
    logic [31:0] imm_ext;
    logic [31:0] alu_op_a;
    logic [31:0] alu_op_b;
    logic [31:0] alu_result;
    logic [31:0] wr_data;

    logic [31:0] branch_target;
    logic [31:0] jal_target;
    logic [31:0] jalr_target;

    assign instr = instr_i;

    // --- PC ---
    program_counter u_pc (
        .clk_i     (clk_i),
        .rst_i     (rst_i),
        .pc_en_i   (pc_en_i),
        .pc_next_i (pc_next),
        .pc_o      (pc)
    );

    assign pc_o     = pc;
    assign pc_plus4 = pc + 32'd4;

    // --- Banco de registros ---
    register_file u_regfile (
        .clk_i (clk_i),
        .we_i  (reg_write_i),
        .rs1_i (instr[19:15]),
        .rs2_i (instr[24:20]),
        .rd_i  (instr[11:7]),
        .wd_i  (wr_data),
        .rd1_o (rs1_data),
        .rd2_o (rs2_data)
    );

    // --- Extensión de signo ---
    sign_extend u_sext (
        .instr_i   (instr),
        .imm_src_i (imm_src_i),
        .imm_ext_o (imm_ext)
    );

    // --- MUX operando A de ALU ---
    // 00 = rs1 normal
    // 01 = zero para lui:   rd = 0 + imm_U
    // 10 = PC para auipc:   rd = PC + imm_U
    always_comb begin
        case (alu_op_a_src_i)
            2'b00:   alu_op_a = rs1_data;
            2'b01:   alu_op_a = 32'h0000_0000;
            2'b10:   alu_op_a = pc;
            default: alu_op_a = rs1_data;
        endcase
    end

    // --- MUX operando B de ALU ---
    assign alu_op_b = alu_src_i ? imm_ext : rs2_data;

    // --- ALU ---
    alu u_alu (
        .a_i         (alu_op_a),
        .b_i         (alu_op_b),
        .alu_ctrl_i  (alu_ctrl_i),
        .result_o    (alu_result),
        .zero_o      (alu_zero_o),
        .lt_signed_o (alu_lt_signed_o)
    );

    // --- Targets de salto ---
    assign branch_target = pc + imm_ext;
    assign jal_target    = pc + imm_ext;
    assign jalr_target   = rs1_data + imm_ext;

    // --- MUX próximo PC ---
    always_comb begin
        case (pc_next_src_i)
            2'b00:   pc_next = pc_plus4;
            2'b01:   pc_next = branch_target;
            2'b10:   pc_next = jal_target;
            2'b11:   pc_next = {jalr_target[31:1], 1'b0};
            default: pc_next = pc_plus4;
        endcase
    end

    // --- MUX resultado a escribir en rd ---
    always_comb begin
        case (result_src_i)
            2'b00:   wr_data = alu_result;
            2'b01:   wr_data = data_rdata_i;
            2'b10:   wr_data = pc_plus4;
            default: wr_data = alu_result;
        endcase
    end

    // --- Salidas hacia bus de datos ---
    assign data_addr_o  = alu_result;
    assign data_wdata_o = rs2_data;
    assign data_we_o    = mem_write_i;

endmodule