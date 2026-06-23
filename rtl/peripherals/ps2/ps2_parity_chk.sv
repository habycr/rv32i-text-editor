// Revisa si una trama PS/2 recibida terminó correctamente.
// En este bloque se valida la paridad impar de los 8 bits de datos y también
// que el bit de stop venga en alto.

// El start bit no se revisa aquí porque ya lo detecta la FSM de recepción
// antes de empezar a desplazar la trama.

// Validador simple de la trama recibida.
module ps2_parity_chk (
	// Trama completa capturada por ps2_rx_frame.
	input  logic [10:0] frame_i,    // trama completa al finalizar la recepción
	// Vale 1 cuando paridad y stop bit son correctos.
	output logic        frame_ok_o, // 1 = trama válida
	// Vale 1 cuando la paridad impar coincide.
	output logic        parity_ok_o // 1 = paridad impar correcta
);

	// XOR de los 8 bits de datos recibidos.
	logic parity_calc;
	// Primero se calcula la paridad de los datos.
	assign parity_calc = ^frame_i[8:1];  // XOR de los 8 bits de datos
	// Con paridad impar, datos XOR paridad debe dar 1.
	assign parity_ok_o = parity_calc ^ frame_i[9];
	// La trama se acepta solo si también trae stop bit en alto.
	assign frame_ok_o  = parity_ok_o && frame_i[10];

endmodule
