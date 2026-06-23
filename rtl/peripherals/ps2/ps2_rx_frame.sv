// Guarda los bits que llegan desde el teclado PS/2.
// Cada vez que la FSM indica que hay que capturar un bit, este módulo lo mete
// en un registro de desplazamiento hasta formar la trama completa de 11 bits.

// La trama PS/2 viene con start, 8 bits de datos, paridad y stop.
// El byte útil queda separado en rx_byte_o para que el periférico pueda guardarlo.

// Recibe señales de control de la FSM y entrega la trama recibida.
module ps2_rx_frame (
	// Reloj del sistema.
	input  logic       clk_i,
	// Reset activo en bajo.
	input  logic       rst_i,
	// Pulso de captura generado por la FSM.
	input  logic       bit_shift_i,      // pulso = captura el bit actual
	// Bit PS/2 ya sincronizado al reloj interno.
	input  logic       ps2_data_sync_i,  // dato sincronizado
	// Limpia el registro antes de iniciar una nueva trama.
	input  logic       frame_clear_i,    // limpia el registro al comenzar nueva trama
	// Trama completa recibida.
	output logic [10:0] frame_o,          // trama completa [10]=último bit capturado
	// Byte de datos extraído de la trama.
	output logic [7:0]  rx_byte_o         // bits de datos [8:1] de la trama
);

	// Registro donde se van acumulando los 11 bits recibidos.
	logic [10:0] frame_reg;

	// Actualiza el shift register con cada bit recibido.
	always_ff @(posedge clk_i or negedge rst_i) begin
		if (!rst_i) begin
			// En reposo, las líneas PS/2 permanecen en alto.
			frame_reg <= 11'h7FF;  // línea idle = 1
		end else begin
			if (frame_clear_i)
				frame_reg <= 11'h7FF;
			else if (bit_shift_i)
				// El nuevo bit entra por arriba y la trama se acomoda con cada flanco.
				frame_reg <= {ps2_data_sync_i, frame_reg[10:1]};
		end
	end

	// Se expone la trama completa para validarla después.
	assign frame_o    = frame_reg;
	// Los bits de datos quedan en las posiciones [8:1] de la trama.
	assign rx_byte_o  = frame_reg[8:1];

endmodule
