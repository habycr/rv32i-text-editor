// Genera los pulsos de tiempo que usa la UART para trabajar a 115200 baud.
// El diseño asume un reloj de 25 MHz, por eso cada bit dura aproximadamente
// 217 ciclos de reloj.

// La salida baud_tick_o marca el final de un bit.
// La salida sample_tick_o marca un punto cercano al centro del bit,
// que es el momento más cómodo para muestrear en recepción.

module baud_gen (
	// Reloj del sistema usado por la UART.
	input  logic clk_i,

	// Reset activo en bajo.
	input  logic rst_i,

	// Reinicia el contador interno al comienzo de una trama.
	// Esto ayuda a que TX y RX alineen sus tiempos desde el primer bit.
	input  logic restart_i,

	// Pulso de un ciclo cuando se completa el tiempo de un bit.
	output logic baud_tick_o,

	// Pulso de un ciclo cerca de la mitad del tiempo de un bit.
	output logic sample_tick_o
);

	// Cantidad aproximada de ciclos para un bit UART con reloj de 25 MHz.
	localparam int DIVISOR  = 217;

	// Punto medio del bit. Se usa principalmente para recepción.
	localparam int HALF_DIV = 108;

	// Contador interno del generador de tiempos.
	logic [7:0] cnt;

	always_ff @(posedge clk_i or negedge rst_i) begin
		// Con reset activo, el contador vuelve a cero.
		if (!rst_i)
			cnt <= 8'd0;

		// Cuando empieza una trama nueva, se realinea el conteo.
		else if (restart_i)
			cnt <= 8'd0;

		// Al llegar al final del periodo de bit, el contador vuelve a empezar.
		else if (cnt == DIVISOR - 1)
			cnt <= 8'd0;

		// Mientras no se llegue al final, se avanza un ciclo más.
		else
			cnt <= cnt + 8'd1;
	end

	// Pulso usado para cambiar de bit o avanzar estados en la UART.
	assign baud_tick_o   = (cnt == DIVISOR - 1);

	// Pulso usado para muestrear el dato recibido cerca del centro del bit.
	assign sample_tick_o = (cnt == HALF_DIV - 1);

endmodule
