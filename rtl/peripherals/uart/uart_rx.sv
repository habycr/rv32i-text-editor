// Receptor UART 8N1.
// Detecta el bit de inicio, toma ocho bits de dato y luego revisa el bit de parada.
// Los bits se guardan LSB primero para reconstruir el byte recibido.

// La FSM pasa por IDLE, START, DATA y STOP.
// El baud_gen interno se reinicia al detectar el flanco de bajada del start bit,
// para que las muestras caigan cerca del centro de cada bit.

module uart_rx (
	// Reloj del sistema.
	input  logic       clk_i,

	// Reset activo en bajo.
	input  logic       rst_i,

	// Línea serial de entrada.
	input  logic       uart_rx_i,

	// Pulso usado por el periférico para limpiar rx_ready_o después de leer RXDATA.
	input  logic       clear_ready_i,

	// Byte recibido.
	output logic [7:0] rx_data_o,

	// Se activa cuando hay un byte nuevo disponible.
	output logic       rx_ready_o,

	// Se activa si el bit de parada no llega en alto.
	output logic       rx_error_o
);

	// Estados principales de la recepción UART.
	typedef enum logic [1:0] {
		IDLE  = 2'b00,
		START = 2'b01,
		DATA  = 2'b10,
		STOP  = 2'b11
	} state_t;

	state_t state;

	// La entrada UART viene de fuera del reloj del sistema.
	// Por eso primero se sincroniza con dos flip-flops y luego se detecta
	// el flanco de bajada que marca el posible start bit.
	logic rx_sync1, rx_sync2, rx_prev, fall_edge;
	always_ff @(posedge clk_i or negedge rst_i) begin
		if (!rst_i) begin
			rx_sync1 <= 1'b1;
			rx_sync2 <= 1'b1;
			rx_prev  <= 1'b1;
		end else begin
			rx_sync1 <= uart_rx_i;
			rx_sync2 <= rx_sync1;
			rx_prev  <= rx_sync2;
		end
	end
	assign fall_edge = rx_prev & ~rx_sync2;

	// El baud_gen se reinicia justo al detectar el inicio de una trama.
	// Con eso, sample_tick queda alineado hacia el centro del bit recibido.
	logic baud_restart, sample_tick;
	assign baud_restart = (state == IDLE) && fall_edge;

	baud_gen u_baud (
		.clk_i         (clk_i),
		.rst_i         (rst_i),
		.restart_i     (baud_restart),
		.baud_tick_o   (),
		.sample_tick_o (sample_tick)
	);

	// bit_cnt indica cuál bit de dato se está recibiendo.
	logic [2:0] bit_cnt;

	// Registro temporal donde se arma el byte recibido.
	logic [7:0] shift_reg;

	always_ff @(posedge clk_i or negedge rst_i) begin
		if (!rst_i) begin
			state      <= IDLE;
			bit_cnt    <= 3'd0;
			shift_reg  <= 8'd0;
			rx_data_o  <= 8'd0;
			rx_ready_o <= 1'b0;
			rx_error_o <= 1'b0;
		end else begin
			// El periférico limpia esta bandera cuando el CPU lee RXDATA.
			if (clear_ready_i)
				rx_ready_o <= 1'b0;

			case (state)
				IDLE: begin
					// En reposo se espera un flanco de bajada en la línea RX.
					bit_cnt <= 3'd0;
					if (fall_edge) begin
						state      <= START;
						rx_error_o <= 1'b0;
					end
				end

				START: begin
					// En el centro del start bit se confirma que la línea siga en 0.
					// Si volvió a 1, era ruido o un pulso falso.
					if (sample_tick) begin
						if (rx_sync2 == 1'b0) begin
							state   <= DATA;
							bit_cnt <= 3'd0;
						end else begin
							state   <= IDLE;
						end
					end
				end

				DATA: begin
					// Cada sample_tick toma un bit de dato en el centro de su periodo.
					if (sample_tick) begin
						shift_reg[bit_cnt] <= rx_sync2;
						if (bit_cnt == 3'd7)
							state <= STOP;
						else
							bit_cnt <= bit_cnt + 3'd1;
					end
				end

				STOP: begin
					// El bit de parada debe estar en 1.
					// Si está correcto, se publica el byte recibido.
					if (sample_tick) begin
						state <= IDLE;
						if (rx_sync2 == 1'b1) begin
							rx_data_o  <= shift_reg;
							rx_ready_o <= 1'b1;
							rx_error_o <= 1'b0;
						end else begin
							rx_error_o <= 1'b1;
						end
					end
				end

				default: state <= IDLE;
			endcase
		end
	end

endmodule
