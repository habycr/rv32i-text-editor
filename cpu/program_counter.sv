// Program Counter — registra la dirección de la instrucción actual
// Actualiza en cada flanco de subida SOLO si pc_en_i está activo; reset
// activo en bajo a 0x00000000.
//
// pc_en_i (activo en alto) permite mantener (hold) el PC durante un ciclo
// de stall, por ejemplo el ciclo extra que requiere 'lw' mientras espera el
// dato sincrono de la RAM (ver cpu/riscv_cpu.sv). Cuando pc_en_i = 0, el PC
// conserva su valor actual en el siguiente flanco de subida en lugar de
// avanzar a pc_next_i.
module program_counter (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        pc_en_i,
    input  logic [31:0] pc_next_i,
    output logic [31:0] pc_o
);
    always_ff @(posedge clk_i or negedge rst_i) begin
        if (!rst_i)
            pc_o <= 32'h0000_0000;
        else if (pc_en_i)
            pc_o <= pc_next_i;
        // else: pc_en_i = 0 -> mantiene pc_o (stall)
    end
endmodule
