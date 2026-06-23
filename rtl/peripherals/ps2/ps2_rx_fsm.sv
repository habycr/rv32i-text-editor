// Controla la recepción de una trama PS/2 desde el teclado.
// La FSM espera el start bit, cuenta los 11 bits de la trama y luego revisa
// si el frame recibido fue válido usando la señal del verificador de paridad.

// Si el host está transmitiendo hacia el teclado, la recepción se inhibe.
// Esto evita que los flancos generados por el propio host se confundan con datos RX.

// FSM encargada de decidir cuándo capturar, validar o descartar una trama.
module ps2_rx_fsm (
	// Reloj del sistema.
	input  logic       clk_i,
	// Reset activo en bajo.
	input  logic       rst_i,
	// Pulso de un ciclo cuando aparece un flanco descendente en PS/2 CLK.
	input  logic       fall_edge_i,      // flanco desc. sincronizado de ps2_clk
	// Dato PS/2 ya sincronizado.
	input  logic       ps2_data_sync_i,  // dato sincronizado
	// Resultado de la revisión de paridad y stop bit.
	input  logic       frame_ok_i,       // resultado del verificador de paridad/stop
	// Habilita o bloquea la recepción desde software.
	input  logic       kbd_enable_i,     // habilita recepción
	// Se activa mientras el host transmite para no mezclar TX con RX.
	input  logic       rx_inhibit_i,     // 1 = inhibe RX (host transmitiendo)
	// Ordena al registro de trama capturar el bit actual.
	output logic       bit_shift_o,      // pulso: captura bit en ps2_rx_frame
	// Limpia la trama justo cuando se detecta un nuevo start bit.
	output logic       frame_clear_o,    // limpia ps2_rx_frame al iniciar trama
	// Cuenta cuántos bits de la trama se han capturado.
	output logic [3:0] bit_count_o,      // número de bits capturados (0..10)
	// Indica que la trama completa ya fue recibida y aceptada.
	output logic       frame_done_o,     // pulso al completar 11 bits
	// Se activa si la trama terminó con error.
	output logic       rx_error_o        // 1 = trama con error (paridad/stop)
);

	// Estados principales del proceso de recepción.
	typedef enum logic [2:0] {
		IDLE  = 3'd0,
		SHIFT = 3'd1,
		CHECK = 3'd2,
		DONE  = 3'd3,
		ERROR = 3'd4
	} state_t;

	// Estado actual y siguiente estado de la FSM.
	state_t     state, state_next;
	// Contador interno de bits capturados.
	logic [3:0] bit_cnt;

	// Registro de estado y contador de bits.
	always_ff @(posedge clk_i or negedge rst_i) begin
		if (!rst_i) begin
			state   <= IDLE;
			bit_cnt <= 4'd0;
		end else begin
			state <= state_next;
			case (state)
				IDLE:  bit_cnt <= 4'd0;
				SHIFT: if (fall_edge_i) bit_cnt <= bit_cnt + 4'd1;
				default: ;
			endcase
		end
	end

	// Lógica combinacional que decide el siguiente estado.
	always_comb begin
		state_next = state;
		if (rx_inhibit_i) begin
			state_next = IDLE;
		end else
		case (state)
			IDLE: begin
				if (fall_edge_i && ps2_data_sync_i == 1'b0 && kbd_enable_i)
					state_next = SHIFT;
			end
			SHIFT: begin
				if (fall_edge_i && bit_cnt == 4'd9)
					state_next = CHECK;
			end
			CHECK: begin
				if (frame_ok_i) state_next = DONE;
				else            state_next = ERROR;
			end
			DONE:  state_next = IDLE;
			ERROR: state_next = IDLE;
		endcase
	end

	// Salidas directas de control hacia el capturador de trama.
	assign bit_shift_o   = !rx_inhibit_i && (state == SHIFT) && fall_edge_i;
	assign frame_clear_o = !rx_inhibit_i && (state == IDLE)  && fall_edge_i && ps2_data_sync_i == 1'b0 && kbd_enable_i;
	assign bit_count_o   = bit_cnt;
	assign frame_done_o  = !rx_inhibit_i && (state == DONE);
	assign rx_error_o    = !rx_inhibit_i && (state == ERROR);

endmodule
