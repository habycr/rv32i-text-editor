// Memoria RAM de datos del sistema.
// Trabaja con direcciones locales generadas por el address translator,
// no con la dirección completa de 32 bits que sale directamente de la CPU.

module ram (
	// Reloj principal del sistema.
	// Las escrituras y lecturas de la RAM se registran en el flanco de subida.
	input  logic        clk,

	// Dirección local que llega desde el traductor de direcciones.
	// Solo se usan algunos bits para seleccionar la palabra dentro de la RAM.
	input  logic [12:0] local_addr_o,

	// Señal de escritura que viene propagada desde la CPU.
	input  logic        we_o,

	// Chip-select de RAM.
	// Permite que la memoria responda solo cuando la dirección realmente cae en su rango.
	input  logic        cs_ram_o,

	// Dato que la CPU quiere guardar en memoria cuando hay una escritura válida.
	input  logic [31:0] DataOut_o,

	// Dato leído desde la RAM.
	// Como la lectura es síncrona, este valor se actualiza en el flanco de reloj.
	output logic [31:0] ram_data_o
);

	// Índice interno de palabra dentro de la RAM.
	// La memoria tiene 1024 palabras, por eso se necesitan 10 bits.
	logic [9:0] dir_ram;

	// Escritura real hacia la RAM.
	// Solo se activa cuando la CPU pide escribir y la RAM fue seleccionada.
	logic       ram_we;

	// RAM de 1024 palabras de 32 bits.
	// En total son 4096 bytes, es decir, 4 KB.
	(* ramstyle = "M10K, no_rw_check" *)
	logic [31:0] ram [0:1023];

	// Convierte la dirección local en índice de palabra.
	// Se descartan los bits [1:0] porque cada palabra ocupa 4 bytes.
	// También queda fuera el bit [12], ya que la RAM interna solo indexa 4 KB.
	assign dir_ram = local_addr_o[11:2];

	// La escritura solo se permite si la CPU activó we_o y el traductor seleccionó RAM.
	assign ram_we = we_o & cs_ram_o;

	// Aviso solo para simulación.
	// Si el bit [12] viene en 1, la dirección se sale del tamaño real de esta RAM.
	// Como dir_ram ignora ese bit, se muestra una advertencia para detectar el acceso.
	// synthesis translate_off
	always_ff @(posedge clk) begin
		if (ram_we && local_addr_o[12])
			$warning("ram_nivel3: acceso fuera de rango (addr=0x%0h), bit[12] ignorado", local_addr_o);
	end
	// synthesis translate_on

	// Escritura síncrona.
	// El dato se guarda en la palabra seleccionada durante el flanco de subida.
	always_ff @(posedge clk) begin
		if (ram_we) begin
			ram[dir_ram] <= DataOut_o;
		end
	end

	// Lectura síncrona.
	// El dato de salida queda registrado, por lo que aparece un ciclo después
	// de presentar la dirección correspondiente.
	//
	// Esto permite inferir una RAM M10K de forma más limpia, pero obliga al CPU
	// a manejar la latencia de un ciclo en instrucciones de carga como lw.
	always_ff @(posedge clk) begin
		ram_data_o <= ram[dir_ram];
	end

endmodule
