// Transmite comandos desde el host hacia el teclado PS/2.
// El módulo sigue la secuencia del protocolo: retiene CLK en bajo, baja DATA,
// envía la trama bit por bit y finalmente espera el ACK del teclado.

// Las líneas se manejan como open-drain: el módulo solo fuerza bajos.
// Cuando no necesita controlar la línea, deja el drive inactivo para que el pull-up
// externo mantenga el nivel alto.

// Interfaz del transmisor PS/2.
module ps2_tx (
	// Reloj del sistema.
	input  logic       clk_i,
	// Reset activo en bajo.
	input  logic       rst_i,
	// Pulso para iniciar el envío del comando.
	input  logic       tx_start_i,
	// Byte que se quiere enviar al teclado.
	input  logic [7:0] tx_data_i,
	// Reloj PS/2 ya sincronizado.
	input  logic       ps2_clk_sync_i,
	// Dato PS/2 ya sincronizado, usado para leer el ACK.
	input  logic       ps2_data_sync_i,
	// Cuando vale 1, el host fuerza CLK a bajo.
	output logic       ps2_clk_drive_o,
	// Cuando vale 1, el host fuerza DATA a bajo.
	output logic       ps2_data_drive_o,
	// Indica que el transmisor está libre para otro comando.
	output logic       tx_ready_o,
	// Se activa si ocurre timeout o no llega el ACK.
	output logic       tx_error_o
);

	// Tiempos calculados para clk_i de 25 MHz.
	localparam int HOLD_CYCLES       = 2500;   // 100 us
	localparam int DATA_SETUP_CYCLES = 25;     // 1 us
	localparam int ACK_TIMEOUT       = 50000;  // 2 ms
	localparam int BIT_TIMEOUT       = 50000;  // 2 ms

	// Estados de la secuencia de transmisión PS/2.
	typedef enum logic [2:0] {
		IDLE      = 3'd0,
		HOLD_CLK  = 3'd1,
		PULL_DATA = 3'd2,
		SEND_BIT  = 3'd3,
		WAIT_ACK  = 3'd4,
		TX_DONE   = 3'd5,
		TX_ERROR  = 3'd6
	} state_t;

	// Estado actual del transmisor.
	state_t      state;
	// Siguiente estado calculado de forma combinacional.
	state_t      state_next;
	// Temporizador para esperas y timeouts.
	logic [16:0] timer;
	// Cuenta los bits enviados de la trama.
	logic [3:0]  bit_cnt;
	// Trama completa que se va desplazando durante el envío.
	logic [10:0] shift_reg;
	// Paridad impar calculada a partir del byte de datos.
	logic        parity_bit;
	// Flanco descendente detectado en el reloj PS/2.
	logic        fall_ps2;
	// Muestra anterior de PS/2 CLK para detectar el flanco.
	logic        clk_prev;

	// Registro principal de la FSM y de los datos que se transmiten.
	always_ff @(posedge clk_i or negedge rst_i) begin
		if (!rst_i)
			clk_prev <= 1'b1;
		else
			clk_prev <= ps2_clk_sync_i;
	end

	// Detecta el flanco donde el teclado toma o confirma cada bit.
	assign fall_ps2   = clk_prev & ~ps2_clk_sync_i;
	assign parity_bit = ~(^tx_data_i);

	// Registro principal de la FSM y de los datos que se transmiten.
	always_ff @(posedge clk_i or negedge rst_i) begin
		if (!rst_i) begin
			state      <= IDLE;
			timer      <= 17'd0;
			bit_cnt    <= 4'd0;
			shift_reg  <= 11'h7FF;
			tx_error_o <= 1'b0;
		end else begin
			state <= state_next;

			if (state != state_next)
				timer <= 17'd0;
			else if (state == SEND_BIT && fall_ps2)
				timer <= 17'd0;
			else
				timer <= timer + 17'd1;

			case (state)
				IDLE: begin
					tx_error_o <= 1'b0;

					if (tx_start_i) begin
						shift_reg <= {1'b1, parity_bit, tx_data_i, 1'b0};
						bit_cnt   <= 4'd0;
					end
				end

				SEND_BIT: begin
					if (fall_ps2) begin
						shift_reg <= {1'b1, shift_reg[10:1]};
						bit_cnt   <= bit_cnt + 4'd1;
					end
				end

				WAIT_ACK: begin
					if (timer >= ACK_TIMEOUT)
						tx_error_o <= 1'b1;
				end

				TX_ERROR: begin
					tx_error_o <= 1'b1;
				end

				default: begin
				end
			endcase
		end
	end

	// Calcula el siguiente estado según tiempos, flancos y ACK.
	always_comb begin
		state_next = state;

		case (state)
			IDLE: begin
				if (tx_start_i)
					state_next = HOLD_CLK;
			end

			HOLD_CLK: begin
				if (timer >= HOLD_CYCLES)
					state_next = PULL_DATA;
			end

			PULL_DATA: begin
				if (timer >= DATA_SETUP_CYCLES)
					state_next = SEND_BIT;
			end

			SEND_BIT: begin
				if (fall_ps2 && bit_cnt == 4'd10)
					state_next = WAIT_ACK;
				else if (timer >= BIT_TIMEOUT)
					state_next = TX_ERROR;
			end

			WAIT_ACK: begin
				if (timer >= ACK_TIMEOUT)
					state_next = TX_ERROR;
				else if (!ps2_data_sync_i && fall_ps2)
					state_next = TX_DONE;
			end

			TX_DONE: begin
				state_next = IDLE;
			end

			TX_ERROR: begin
				state_next = IDLE;
			end

			default: begin
				state_next = IDLE;
			end
		endcase
	end

	// Salidas open-drain: solo indican cuándo forzar bajo.
	assign ps2_clk_drive_o  = (state == HOLD_CLK) || (state == PULL_DATA);
	assign ps2_data_drive_o = (state == PULL_DATA) ||
							  ((state == SEND_BIT) && ~shift_reg[0]);
	assign tx_ready_o       = (state == IDLE);

endmodule
