// Separa la dirección que viene desde la CPU en partes más fáciles de usar.
// Este módulo no decide si la dirección pertenece a RAM, VGA, UART u otro periférico;
// solo entrega los campos necesarios para que otros bloques hagan esa decisión.

// La ventaja de tener este módulo es que los cortes de bits se hacen en un solo lugar.
// Así se evita repetir addr_i[31:16], addr_i[15:0] o addr_i[12:0] en varios módulos.

module address_splitter (
    // Dirección completa generada por la CPU.
    // Esta dirección puede apuntar a memoria RAM o a alguno de los periféricos
    // definidos en el mapa del sistema.
    input  logic [31:0] addr_i,

    // Parte alta de la dirección.
    // Sirve para identificar la región general del mapa de memoria.
    // Por ejemplo, las direcciones 0x0001_xxxx pertenecen al espacio de periféricos.
    output logic [15:0] addr_region_o,

    // Parte baja de la dirección.
	 
    // Cuando la región es 0x0001, este valor funciona como offset interno
    // para saber qué periférico se está direccionando.
    output logic [15:0] periph_offset_o,

    // Dirección local cruda tomada de los bits bajos.
    // Es útil para bloques que solo necesitan trabajar con un rango pequeño
    // de direcciones internas, como la RAM o buffers de periféricos.
    output logic [12:0] raw_local_addr_o
);

    // Extrae la región principal de la dirección.
    // Ejemplo: 0x0001_0040 produce una región 0x0001.
    assign addr_region_o = addr_i[31:16];

    // Extrae el offset dentro de esa región.
    // Ejemplo: 0x0001_0040 produce un offset 0x0040.
    assign periph_offset_o = addr_i[15:0];

    // Conserva los bits bajos como dirección local.
    // En el caso de la RAM, una dirección como 0x0000_2000 queda alineada
    // con el inicio local del bloque.
    assign raw_local_addr_o = addr_i[12:0];

endmodule