// Contador principal del timer.
// Guarda el valor de recarga, lleva la cuenta regresiva y genera las banderas
// que luego lee el periférico por medio de sus registros.

// El contador solo baja cuando el timer está corriendo y llega un tick del prescaler.
// También maneja start, stop, clear, autoreload y escrituras nuevas de DATA.
// El reset es activo en bajo, igual que en el resto del proyecto.

module timer_counter (
	input  logic        clk_i,
	input  logic        rst_i,

	// Pulso de tick del prescaler: decrementa el contador cuando está corriendo
	input  logic        tick_i,

	// Comandos de control desde timer_peripheral
	input  logic        start_write_i,     // 1 = escritura al bit start en este ciclo
	input  logic        start_value_i,     // valor del bit start en esa escritura
	input  logic        stop_cmd_i,        // 1 = comando stop: detener inmediatamente
	input  logic        clear_cmd_i,       // 1 = comando clear: recargar desde reload_reg
	input  logic        autoreload_write_i,// 1 = escritura al bit autoreload en este ciclo
	input  logic        autoreload_value_i,// valor del bit autoreload en esa escritura
	input  logic        data_write_i,      // 1 = escritura de DATA: actualiza reload y count
	input  logic [31:0] data_value_i,      // valor a cargar en reload_reg y count_reg

	// Estado actual del timer (hacia timer_peripheral)
	output logic        running_o,         // 1 = timer corriendo
	output logic        autoreload_o,      // 1 = recarga automática habilitada
	output logic        timeout_o,         // 1 = timeout ocurrió y no fue limpiado aún
	output logic [31:0] count_o            // valor actual del contador
);

	// Registros que guardan el estado real del timer.
	logic        running_reg;
	logic        autoreload_reg;
	logic        timeout_reg;
	logic [31:0] count_reg;
	logic [31:0] reload_reg;   // valor de recarga / valor inicial

	// Lógica principal del contador.
	always_ff @(posedge clk_i or negedge rst_i) begin
		if (!rst_i) begin
			running_reg    <= 1'b0;
			autoreload_reg <= 1'b0;
			timeout_reg    <= 1'b0;
			count_reg      <= 32'd0;
			reload_reg     <= 32'd0;
		end else begin

			// 1. Escritura de DATA: máxima prioridad entre comandos de
			//    control. Actualiza valor de recarga Y valor actual,
			//    y limpia timeout. El estado running no cambia.
			if (data_write_i) begin
				reload_reg  <= data_value_i;
				count_reg   <= data_value_i;
				timeout_reg <= 1'b0;
				// running_reg no se toca: la documentación dice "keep running unchanged"
			end

			// 2. Comando CLEAR: recarga desde reload_reg, limpia timeout.
			//    Se puede combinar con data_write_i en el mismo ciclo;
			//    en ese caso, data_write_i carga primero (ver prioridad
			//    secuencial: ambos escriben count_reg, el último gana).
			//    Para evitar ambigüedad, clear_cmd_i y data_write_i no
			//    deberían ser activos en el mismo ciclo (el periférico
			//    garantiza que son offsets distintos: 13'h000 vs 13'h004).
			if (clear_cmd_i && !data_write_i) begin
				count_reg   <= reload_reg;
				timeout_reg <= 1'b0;
			end

			// 3. Comando STOP: detiene el timer. Prioridad sobre start.
			if (stop_cmd_i) begin
				running_reg <= 1'b0;
			end

			// 4. Bit START (set-only): escribir bit0 = 1 ARRANCA el timer.
			//    Escribir bit0 = 0 NO lo detiene — para eso está STOP (bit1).
			//    Así un comando CLEAR (0x10) u otra escritura a CTRL con
			//    bit0 = 0 no apaga el conteo por accidente.
			//    STOP tiene prioridad: si llegan start y stop juntos, gana stop.
			if (start_write_i && start_value_i && !stop_cmd_i) begin
				running_reg <= 1'b1;
			end

			// 5. Escritura de bit AUTORELOAD
			if (autoreload_write_i) begin
				autoreload_reg <= autoreload_value_i;
			end

			// 6. Lógica de conteo: solo activa cuando el timer corre y
			//    llega un tick del prescaler. No interfiere con los
			//    comandos anteriores si son de offsets distintos
			//    (el periférico nunca activa tick y data_write al mismo
			//     ciclo con la misma semántica destructiva: tick viene del
			//     prescaler, data_write viene del bus CPU).
			//    Si data_write_i y tick_i coinciden en el mismo ciclo,
			//    data_write_i gana: count_reg queda con data_value_i
			//    porque el bloque 1 se evalúa DENTRO del mismo always_ff
			//    y las asignaciones no bloqueantes se resuelven al final
			//    del delta. Para garantizar comportamiento correcto:
			//    el bloque de tick solo escribe count_reg si !data_write_i.
			if (running_reg && tick_i && !data_write_i && !clear_cmd_i) begin
				if (count_reg <= 32'd1) begin
					// Fin de cuenta. Con count == 1, este tick lo lleva a 0;
					// con count == 0 (valor inicial 0) el timeout es inmediato.
					// En ambos casos el timeout se señala en ESTE tick, de modo
					// que un valor inicial N tarda EXACTAMENTE N ticks (y la
					// recarga automática produce un periodo de N ticks).
					// No se hace underflow a 0xFFFF_FFFF.
					timeout_reg <= 1'b1;
					if (autoreload_reg) begin
						// Recarga automática: periodo exacto de N ticks
						count_reg <= reload_reg;
						// running_reg no cambia: sigue en 1
					end else begin
						// Sin recarga: detener y quedarse en 0
						count_reg   <= 32'd0;
						running_reg <= 1'b0;
					end
				end else begin
					// Decremento normal
					count_reg <= count_reg - 32'd1;
				end
			end

		end // else: not reset
	end // always_ff

	// Salidas
	assign running_o    = running_reg;
	assign autoreload_o = autoreload_reg;
	assign timeout_o    = timeout_reg;
	assign count_o      = count_reg;

endmodule
