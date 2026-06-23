
// Selecciona la dirección local que se va a mandar al bus interno.
// La RAM y los periféricos calculan su propio offset por separado;
// este módulo solo decide cuál de esos dos valores debe salir.

module local_address_mux (
    // Chip-select de RAM.
    // Si está activo, la dirección local debe venir del decodificador de RAM.
    input  logic        cs_ram_i,

    // Chip-selects de los periféricos.
    // Si cualquiera de estos está activo, se usa la dirección local
    // que calculó el decodificador de periféricos.
    input  logic        cs_uart_i,
    input  logic        cs_ps2_i,
    input  logic        cs_timer_i,
    input  logic        cs_vga_ctrl_i,
    input  logic        cs_vga_buffer_i,

    // Offset interno calculado para la RAM.
    input  logic [12:0] ram_local_addr_i,

    // Offset interno calculado para el periférico seleccionado.
    input  logic [12:0] periph_local_addr_i,

    // Dirección local final que recibe el bloque seleccionado.
    output logic [12:0] local_addr_o
);

    always_comb begin
        // Valor por defecto.
        // Si ninguna selección está activa, se deja la dirección en cero.
        local_addr_o = 13'b0;

        // Para accesos a RAM, se entrega directamente el offset de RAM.
        if (cs_ram_i) begin
            local_addr_o = ram_local_addr_i;
        end

        // Para cualquier periférico válido, se entrega el offset generado
        // por el decodificador de periféricos.
        else if (cs_uart_i | cs_ps2_i | cs_timer_i |
                 cs_vga_ctrl_i | cs_vga_buffer_i) begin

            local_addr_o = periph_local_addr_i;
        end
    end

endmodule
