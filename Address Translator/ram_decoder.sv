// Decodifica el rango de RAM dentro del mapa de memoria.
// Si la dirección de la CPU cae dentro de 0x0000_2000 a 0x0000_2FFF,
// este módulo activa el chip-select de RAM y entrega el offset local correspondiente.

module ram_decoder (
// Dirección completa generada por la CPU.
// Se compara contra el rango absoluto donde está ubicada la RAM.
input logic [31:0] addr_i,

// Dirección local cruda que viene del address_splitter.
// En el rango de RAM, estos bits ya representan la posición interna
// dentro del bloque de memoria.
input  logic [12:0] raw_local_addr_i,

// Chip-select de RAM.
// Solo se activa cuando la dirección pertenece al rango asignado a RAM.
output logic        cs_ram_o,

// Dirección local que se entrega a la RAM.
// Si el acceso no es para RAM, se mantiene en cero.
output logic [12:0] ram_local_addr_o

);

// Dirección base de la RAM de datos en el mapa global.
localparam logic [31:0] RAM_BASE = 32'h0000_2000;

// Última dirección válida de la RAM de datos.
// Este rango cubre 4 KB, desde 0x2000 hasta 0x2FFF.
localparam logic [31:0] RAM_END  = 32'h0000_2FFF;

always_comb begin
	// Valores seguros por defecto.
	// Con esto, si la dirección no coincide, la RAM queda desactivada
	// y no se conserva ningún valor anterior.
	cs_ram_o         = 1'b0;
	ram_local_addr_o = 13'b0;

	// La RAM solo responde cuando la dirección está dentro de su rango.
	if ((addr_i >= RAM_BASE) && (addr_i <= RAM_END)) begin
		cs_ram_o         = 1'b1;

		// Para RAM se usa directamente el offset generado con los bits bajos.
		// Por ejemplo:
		//   0x0000_2000 -> 0x0000
		//   0x0000_2004 -> 0x0004
		//   0x0000_2FFF -> 0x0FFF
		ram_local_addr_o = raw_local_addr_i;
	end
end

endmodule