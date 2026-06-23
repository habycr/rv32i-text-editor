// Memoria ROM de instrucciones del procesador.
// Guarda el programa que ejecuta la CPU y entrega una instrucción de 32 bits
// según la dirección de programa que llega desde el contador de programa.

module rom #(
	// Archivo hexadecimal usado para inicializar la ROM.
	// Si se deja vacío, la memoria queda cargada únicamente con NOPs.
	parameter INIT_FILE = "" //"rom.hex"
)(
	// Reloj del sistema.
	input  logic        clk,

	// Dirección de programa generada por la CPU.
	// Llega en formato de dirección por byte, como en el mapa de memoria.
	input  logic [31:0] ProgAddress_o,

	// Instrucción de 32 bits que se entrega al datapath.
	output logic [31:0] ProgIn_i
);

	// Dirección interna de la ROM.
	// Usa 11 bits porque la memoria tiene 2048 palabras.
	logic [10:0] dir;

	// ROM de 2048 palabras de 32 bits.
	// En total representa 8 KB, ubicados en el mapa global desde
	// 0x0000_0000 hasta 0x0000_1FFF.
	(* ramstyle = "M10K" *)
	logic [31:0] rom [0:2047];

	// Convierte la dirección por byte en dirección por palabra.
	// Se descartan los bits [1:0] porque cada instrucción ocupa 4 bytes.
	// Los bits superiores no se usan aquí; si vienen activos, se avisa solo en simulación.
	assign dir = ProgAddress_o[12:2];

	// Carga inicial segura para toda la ROM.
	// Cada posición arranca con un NOP de RISC-V: ADDI x0, x0, 0.
	// Esto evita que una dirección no cargada tenga basura o una instrucción inesperada.
	initial begin
		for (int i = 0; i < 2048; i = i + 1) begin
			rom[i] = 32'h00000013;
		end
	end

	// Si se indicó un archivo externo, se carga su contenido sobre la ROM.
	// Las posiciones que el archivo no escriba se quedan con el NOP definido arriba.
	initial begin
		if (INIT_FILE != "") begin
			$readmemh(INIT_FILE, rom);
		end
	end

	// Aviso solo para simulación.
	// La ROM real solo cubre 0x0000_0000 a 0x0000_1FFF; si la dirección trae
	// bits altos activos, esos bits se ignoran al formar dir y puede haber aliasing.
	// synthesis translate_off
	always @(*) begin
		if (ProgAddress_o[31:13] != '0)
			$warning("rom_nivel3: direccion fuera de region (0x%0h), bits[31:13] ignorados", ProgAddress_o);
	end
	// synthesis translate_on

	// La lectura se hace en el flanco de bajada.
	// Así la instrucción queda disponible durante la segunda mitad del ciclo,
	// después de que el PC se actualiza en el flanco de subida.
	// Se deja de esta forma para no cambiar la temporización del procesador uniciclo.
	always_ff @(negedge clk) begin
		ProgIn_i <= rom[dir];
	end

endmodule
