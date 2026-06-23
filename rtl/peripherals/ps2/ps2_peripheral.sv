// Periférico PS/2 completo conectado al bus del sistema.
// Integra sincronización, recepción, verificación de trama, transmisión hacia
// el teclado y registros accesibles por la CPU.

// El firmware recibe los bytes Set 2 crudos. Por eso códigos como 0xF0 y 0xE0
// no se eliminan aquí; se dejan para que el software los interprete.

// Mapa local de registros:
// 13'h000 -> CTRL/STATUS: rx_ready, tx_ready, errores y kbd_enable.
// 13'h004 -> RXDATA: último scancode recibido; leerlo limpia rx_ready.
// 13'h008 -> TXDATA: comando hacia el teclado; escribirlo inicia TX si está libre.

// Interfaz principal del periférico hacia el bus y hacia los pines PS/2.
module ps2_peripheral (
	// Reloj del sistema.
	input  logic        clk_i,
	// Reset activo en bajo.
	input  logic        rst_i,
	// Chip-select del periférico PS/2.
	input  logic        cs_i,
	// Indica escritura cuando está en 1; lectura cuando está en 0.
	input  logic        we_i,
	// Offset local generado por el address translator.
	input  logic [12:0] local_addr_i,
	// Dato escrito por la CPU.
	input  logic [31:0] wdata_i,
	// Dato que el periférico devuelve al bus.
	output logic [31:0] rdata_o,
	// Línea de reloj PS/2 desde el conector.
	input  logic        ps2_clk_i,
	// Línea de datos PS/2 desde el conector.
	input  logic        ps2_data_i,
	// Salida open-drain para forzar CLK a bajo durante TX.
	output logic        ps2_clk_o,    // open-drain: drive bajo durante TX
	// Salida open-drain para forzar DATA a bajo durante TX.
	output logic        ps2_data_o    // open-drain: drive bajo durante TX
);

	// Señales externas ya sincronizadas y flanco de captura.
	logic ps2_clk_sync, ps2_data_sync, fall_edge;

	// Señales de control para capturar la trama recibida.
	logic       bit_shift, frame_clear;
	// Contador de bits recibido desde la FSM.
	logic [3:0] bit_count;
	// Resultado de la FSM de recepción.
	logic       frame_done, rx_fsm_error;
	// Trama completa recibida desde el teclado.
	logic [10:0] frame;
	// Byte crudo extraído de la trama PS/2.
	logic [7:0]  rx_byte_raw;
	// Resultado de la validación de paridad y stop.
	logic        frame_ok;

	// Bit de control que habilita la recepción del teclado.
	logic       kbd_enable;
	// Banderas visibles para la CPU en CTRL/STATUS.
	logic       rx_ready, rx_error, tx_error;
	// Último byte recibido y guardado para lectura por CPU.
	logic [7:0] rxdata_reg;

	// Señales de arranque y disponibilidad del transmisor.
	logic       tx_start_pulse, tx_ready;
	// Comando que se enviará al teclado.
	logic [7:0] txdata_reg;

	// Drives internos usados por el transmisor para controlar las líneas.
	logic ps2_clk_drive, ps2_data_drive;

	// Primero se sincronizan las dos líneas físicas del puerto PS/2.
	ps2_sync u_sync (
		.clk_i          (clk_i),
		.rst_i          (rst_i),
		.ps2_clk_i      (ps2_clk_i),
		.ps2_data_i     (ps2_data_i),
		.ps2_clk_sync_o (ps2_clk_sync),
		.ps2_data_sync_o(ps2_data_sync),
		.fall_edge_o    (fall_edge)
	);

	// La FSM decide cuándo capturar bits y cuándo reportar trama completa o error.
	ps2_rx_fsm u_rxfsm (
		.clk_i          (clk_i),
		.rst_i          (rst_i),
		.fall_edge_i    (fall_edge),
		.ps2_data_sync_i(ps2_data_sync),
		.frame_ok_i     (frame_ok),
		.kbd_enable_i   (kbd_enable),
		.rx_inhibit_i   (~tx_ready),       // inhibe RX mientras el host transmite
		.bit_shift_o    (bit_shift),
		.frame_clear_o  (frame_clear),
		.bit_count_o    (bit_count),
		.frame_done_o   (frame_done),
		.rx_error_o     (rx_fsm_error)
	);

	// El registro de trama va acumulando los 11 bits recibidos.
	ps2_rx_frame u_rxframe (
		.clk_i          (clk_i),
		.rst_i          (rst_i),
		.bit_shift_i    (bit_shift),
		.ps2_data_sync_i(ps2_data_sync),
		.frame_clear_i  (frame_clear),
		.frame_o        (frame),
		.rx_byte_o      (rx_byte_raw)
	);

	// Valida paridad impar y stop bit de la trama recibida.
	ps2_parity_chk u_pchk (
		.frame_i    (frame),
		.frame_ok_o (frame_ok),
		.parity_ok_o()   // no se expone externamente
	);

	// Transmisor usado para enviar comandos desde la CPU hacia el teclado.
	ps2_tx u_tx (
		.clk_i           (clk_i),
		.rst_i           (rst_i),
		.tx_start_i      (tx_start_pulse),
		.tx_data_i       (txdata_reg),
		.ps2_clk_sync_i  (ps2_clk_sync),
		.ps2_data_sync_i (ps2_data_sync),
		.ps2_clk_drive_o (ps2_clk_drive),
		.ps2_data_drive_o(ps2_data_drive),
		.tx_ready_o      (tx_ready),
		.tx_error_o      (tx_error)
	);

	// En open-drain solo se fuerza bajo; el alto lo da el pull-up externo.
	assign ps2_clk_o  = ps2_clk_drive  ? 1'b0 : 1'bz;
	assign ps2_data_o = ps2_data_drive ? 1'b0 : 1'bz;

	// Decodificación local de escrituras del bus.
	logic wr_ctrl, wr_txdata, tx_start_req;
	// Escritura al registro CTRL/STATUS.
	assign wr_ctrl   = cs_i && we_i && (local_addr_i == 13'h000);
	// Escritura al registro TXDATA.
	assign wr_txdata = cs_i && we_i && (local_addr_i == 13'h008);

	// Registros de control, datos RX/TX y banderas de estado.
	always_ff @(posedge clk_i or negedge rst_i) begin
		if (!rst_i) tx_start_req <= 1'b0;
		else        tx_start_req <= wr_txdata && tx_ready;
	end
	// Pulso final que arranca el transmisor PS/2.
	assign tx_start_pulse = tx_start_req;

	// Registros de control, datos RX/TX y banderas de estado.
	always_ff @(posedge clk_i or negedge rst_i) begin
		if (!rst_i) begin
			kbd_enable  <= 1'b0;
			txdata_reg  <= 8'h00;
			rxdata_reg  <= 8'h00;
			rx_ready    <= 1'b0;
			rx_error    <= 1'b0;
		end else begin
			if (wr_ctrl)
				kbd_enable <= wdata_i[4];

			if (wr_txdata)
				txdata_reg <= wdata_i[7:0];

			if (frame_done) begin
				rxdata_reg <= rx_byte_raw;
				rx_ready   <= 1'b1;
				rx_error   <= 1'b0;
			end

			if (rx_fsm_error) begin
				rx_error <= 1'b1;
				rx_ready <= 1'b0;
			end

			if (cs_i && !we_i && (local_addr_i == 13'h004))
				rx_ready <= 1'b0;
		end
	end

	// Lectura combinacional de registros para la CPU.
	always_comb begin
		rdata_o = 32'd0;  // cs_i=0 devuelve cero; bits reservados = 0

		if (cs_i && !we_i) begin
			case (local_addr_i)
				13'h000: rdata_o = {27'd0, kbd_enable, tx_error, rx_error, tx_ready, rx_ready};
				13'h004: rdata_o = {24'd0, rxdata_reg};
				13'h008: rdata_o = 32'd0;  // TXDATA es WO
				default: rdata_o = 32'd0;
			endcase
		end
	end

endmodule
