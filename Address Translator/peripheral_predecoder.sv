module peripheral_predecoder (
// Parte alta de la dirección completa.
// Viene del address_splitter y representa la región principal del mapa.
input logic [15:0] addr_region_i,

// Se activa cuando la región corresponde al espacio de periféricos.
output logic cs_periph_space_o

);

always_comb begin
    // Por defecto se asume que la dirección no pertenece a periféricos.
    cs_periph_space_o = 1'b0;

    // La región 0x0001 se usa como página general para periféricos.
    // Si la dirección entra aquí, luego otro decodificador revisa el offset
    // para saber exactamente cuál periférico debe responder.
    if (addr_region_i == 16'h0001) begin
        cs_periph_space_o = 1'b1;
    end
end

endmodule