// Prescaler del timer.
// Divide el reloj de entrada hasta generar un pulso tick_o de un solo ciclo.
// Con los parámetros por defecto, 50 MHz y 1000 Hz, cada tick equivale a 1 ms.

// Cuando enable_i está en cero, el prescaler se queda detenido y no genera ticks.
// El reset es activo en bajo, igual que en el resto del sistema.

module timer_prescaler #(
	parameter int CLK_FREQ_HZ = 50_000_000,
	parameter int TICK_HZ     = 1000
)(
	input  logic clk_i,
	input  logic rst_i,
	input  logic enable_i,   // 1 = prescaler activo; 0 = detenido
	output logic tick_o      // pulso de 1 ciclo de ancho cada 1/TICK_HZ segundos
);

	// Divisor calculado a partir de los parámetros.
	localparam int DIVISOR = CLK_FREQ_HZ / TICK_HZ;

	// Aviso de simulación por si los parámetros no dividen exacto.
	// synthesis translate_off
	initial begin
		if (DIVISOR * TICK_HZ != CLK_FREQ_HZ) begin
			$warning("timer_prescaler: CLK_FREQ_HZ=%0d no es múltiplo exacto de TICK_HZ=%0d. Divisor usado: %0d. Error de frecuencia: %0.4f%%",
				CLK_FREQ_HZ, TICK_HZ, DIVISOR,
				100.0 * (CLK_FREQ_HZ - DIVISOR * TICK_HZ) / CLK_FREQ_HZ);
		end
		if (DIVISOR < 2) begin
			$error("timer_prescaler: DIVISOR=%0d demasiado pequeño (CLK_FREQ_HZ=%0d, TICK_HZ=%0d). Debe ser >= 2.",
				DIVISOR, CLK_FREQ_HZ, TICK_HZ);
		end
	end
	// synthesis translate_on

	// Contador interno del prescaler.
	// $clog2(DIVISOR) bits alcanzan valores de 0 a 2^N - 1.
	// Se usa DIVISOR como límite superior así que necesitamos
	// al menos $clog2(DIVISOR+1) bits para valores hasta DIVISOR-1.
	// Usamos 32 bits para compatibilidad con Quartus; el sintetizador
	// recorta los bits no usados automáticamente.
	logic [31:0] cnt;

	always_ff @(posedge clk_i or negedge rst_i) begin
		if (!rst_i) begin
			cnt    <= 32'd0;
			tick_o <= 1'b0;
		end else begin
			if (!enable_i) begin
				// Si está deshabilitado, se reinicia el conteo y no se emite tick.
				cnt    <= 32'd0;
				tick_o <= 1'b0;
			end else if (cnt == DIVISOR - 1) begin
				// Al final del periodo se genera el tick y el contador vuelve a cero.
				cnt    <= 32'd0;
				tick_o <= 1'b1;
			end else begin
				cnt    <= cnt + 32'd1;
				tick_o <= 1'b0;
			end
		end
	end

endmodule
