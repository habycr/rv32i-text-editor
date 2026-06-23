// CPU RISC-V RV32I monociclo — top que instancia datapath + control unit
// Interfaz según DISENO.md Figura 1
//
// Mantiene el stall de 1 ciclo para 'lw' porque la RAM tiene lectura
// síncrona posedge de 1 ciclo de latencia.

module riscv_cpu (
    input  logic        clk_i,
    input  logic        rst_i,

    // Interfaz de instrucciones (bus ROM)
    output logic [31:0] prog_addr_o,
    input  logic [31:0] prog_in_i,

    // Interfaz de datos (bus RAM + periféricos)
    output logic [31:0] data_addr_o,
    output logic [31:0] data_out_o,
    input  logic [31:0] data_in_i,
    output logic        we_o
);
    // Campos de la instrucción expuestos a la unidad de control
    logic [6:0] opcode, funct7;
    logic [2:0] funct3;

    assign opcode = prog_in_i[6:0];
    assign funct3 = prog_in_i[14:12];
    assign funct7 = prog_in_i[31:25];

    // Señales de control crudas desde control_unit
    logic        reg_write, alu_src, mem_read, mem_write;
    logic [1:0]  result_src;
    logic [3:0]  alu_ctrl;
    logic [2:0]  imm_src;
    logic [1:0]  pc_next_src;
    logic [1:0]  alu_op_a_src;

    // Banderas de la ALU
    logic alu_zero, alu_lt_signed;

    // =========================================================================
    // FSM de stall para 'lw'
    // =========================================================================
    typedef enum logic {
        ST_IDLE      = 1'b0,
        ST_LOAD_WAIT = 1'b1
    } stall_state_e;

    stall_state_e state_q, state_d;

    // 'lw' = opcode I-type load
    logic is_load;
    assign is_load = (opcode == 7'b0000011);

    logic pc_en;
    logic reg_write_eff;

    always_comb begin
        state_d       = ST_IDLE;
        pc_en         = 1'b1;
        reg_write_eff = reg_write;

        unique case (state_q)
            ST_IDLE: begin
                if (is_load) begin
                    // Primer ciclo del lw: se calcula dirección y se pide RAM.
                    // No se escribe rd todavía porque data_in aún no es válido.
                    pc_en         = 1'b0;
                    reg_write_eff = 1'b0;
                    state_d       = ST_LOAD_WAIT;
                end else begin
                    pc_en         = 1'b1;
                    reg_write_eff = reg_write;
                    state_d       = ST_IDLE;
                end
            end

            ST_LOAD_WAIT: begin
                // Segundo ciclo del lw: PC sigue apuntando al mismo lw.
                // Ahora data_in ya es válido, por eso se permite escribir rd.
                pc_en         = 1'b1;
                reg_write_eff = reg_write;
                state_d       = ST_IDLE;
            end

            default: begin
                pc_en         = 1'b1;
                reg_write_eff = reg_write;
                state_d       = ST_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_i) begin
        if (!rst_i)
            state_q <= ST_IDLE;
        else
            state_q <= state_d;
    end

    control_unit u_ctrl (
        .opcode_i        (opcode),
        .funct3_i        (funct3),
        .funct7_i        (funct7),
        .alu_zero_i      (alu_zero),
        .alu_lt_signed_i (alu_lt_signed),
        .reg_write_o     (reg_write),
        .alu_src_o       (alu_src),
        .result_src_o    (result_src),
        .mem_read_o      (mem_read),
        .mem_write_o     (mem_write),
        .alu_ctrl_o      (alu_ctrl),
        .imm_src_o       (imm_src),
        .pc_next_src_o   (pc_next_src),
        .alu_op_a_src_o  (alu_op_a_src)
    );

    riscv_datapath u_dp (
        .clk_i           (clk_i),
        .rst_i           (rst_i),
        .pc_o            (prog_addr_o),
        .instr_i         (prog_in_i),
        .data_addr_o     (data_addr_o),
        .data_wdata_o    (data_out_o),
        .data_rdata_i    (data_in_i),
        .data_we_o       (we_o),
        .reg_write_i     (reg_write_eff),
        .alu_src_i       (alu_src),
        .result_src_i    (result_src),
        .mem_write_i     (mem_write),
        .alu_ctrl_i      (alu_ctrl),
        .imm_src_i       (imm_src),
        .pc_next_src_i   (pc_next_src),
        .alu_op_a_src_i  (alu_op_a_src),
        .pc_en_i         (pc_en),
        .alu_zero_o      (alu_zero),
        .alu_lt_signed_o (alu_lt_signed)
    );

endmodule