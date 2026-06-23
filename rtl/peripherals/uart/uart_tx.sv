// Transmisor UART 8N1.
// Envía un byte por la línea serial usando un bit de inicio, ocho bits de dato
// y un bit de parada. Los datos salen LSB primero, como espera UART estándar.

// La FSM pasa por IDLE, START, DATA y STOP.
// El baud_gen interno marca cuándo se debe avanzar al siguiente bit.

module uart_tx (
	// Reloj del sistema.
	input  logic       clk_i,

	// Reset activo en bajo.
	input  logic       rst_i,

	// Pulso de un ciclo que pide iniciar una transmisión.
	input  logic       tx_start_i,

	// Byte que se va a transmitir cuando tx_start_i está activo.
	input  logic [7:0] tx_data_i,

	// Línea serial de salida hacia el exterior.
	output logic       uart_tx_o,

	// Indica que el transmisor está libre y puede aceptar otro byte.
	output logic       tx_ready_o
);

	// Estados principales de una trama UART.
	typedef enum logic [1:0] {
		IDLE  = 2'b00,
		START = 2'b01,
		DATA  = 2'b10,
		STOP  = 2'b11
	} state_t;

	state_t     state;

	// Cuenta cuántos bits de dato ya se transmitieron.
	logic [2:0] bit_cnt;

	// Guarda el byte mientras se va desplazando bit por bit.
	logic [7:0] shift_reg;

	// Valor que se coloca en la línea UART.
	logic       tx_line;

	// Reinicia el generador de baud justo cuando empieza una trama nueva.
	// Así el start bit dura un periodo completo antes de pasar a DATA.
	logic baud_restart, baud_tick;
	assign baud_restart = (state == IDLE) && tx_start_i;

	baud_gen u_baud (
		.clk_i         (clk_i),
		.rst_i         (rst_i),
		.restart_i     (baud_restart),
		.baud_tick_o   (baud_tick),
		.sample_tick_o ()
	);

	always_ff @(posedge clk_i or negedge rst_i) begin
		if (!rst_i) begin
			state     <= IDLE;
			bit_cnt   <= 3'd0;
			shift_reg <= 8'hFF;
		end else begin
			case (state)
				IDLE: begin
					// En reposo la UART queda lista para recibir un nuevo byte.
					bit_cnt <= 3'd0;

					// El dato se captura al arrancar la transmisión para no depender
					// de cambios posteriores en tx_data_i.
					if (tx_start_i) begin
						shift_reg <= tx_data_i;
						state     <= START;
					end
				end

				START: begin
					// Cuando se cumple el tiempo del start bit, se pasa a enviar datos.
					if (baud_tick) begin
						bit_cnt <= 3'd0;
						state   <= DATA;
					end
				end

				DATA: begin
					// En cada baud_tick sale el bit menos significativo y luego
					// el registro se desplaza para preparar el siguiente bit.
					if (baud_tick) begin
						shift_reg <= {1'b0, shift_reg[7:1]};
						if (bit_cnt == 3'd7)
							state <= STOP;
						else
							bit_cnt <= bit_cnt + 3'd1;
					end
				end

				STOP: begin
					// Después del bit de parada, la UART vuelve a quedar libre.
					if (baud_tick)
						state <= IDLE;
				end

				default: state <= IDLE;
			endcase
		end
	end

	always_comb begin
		// La línea queda en 0 durante START, en el bit actual durante DATA
		// y en 1 durante IDLE/STOP.
		case (state)
			START:   tx_line = 1'b0;
			DATA:    tx_line = shift_reg[0];
			default: tx_line = 1'b1;
		endcase
	end

	assign uart_tx_o  = tx_line;
	assign tx_ready_o = (state == IDLE);

endmodule
