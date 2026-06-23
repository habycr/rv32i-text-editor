// Periférico UART con interfaz al bus local del proyecto.
// Maneja transmisión y recepción 115200-8N1 usando los módulos uart_tx y uart_rx.

// Mapa de registros visto desde address_translator:
//   13'h000  CTRL/STATUS  [0]=tx_ready, [1]=rx_ready, [2]=tx_start
//   13'h004  TXDATA       byte que se quiere transmitir
//   13'h008  RXDATA       byte recibido; al leerlo se limpia rx_ready

// Direcciones absolutas de referencia:
//   0x0001_0040 CTRL/STATUS
//   0x0001_0044 TXDATA
//   0x0001_0048 RXDATA

module uart_peripheral (
	// Reloj del sistema.
	input  logic        clk_i,

	// Reset activo en bajo.
	input  logic        rst_i,

	// Chip-select generado por el address_translator.
	input  logic        cs_i,

	// Señal de escritura del CPU.
	input  logic        we_i,

	// Offset local dentro del periférico UART.
	input  logic [12:0] local_addr_i,

	// Dato escrito por el CPU.
	input  logic [31:0] wdata_i,

	// Dato que el periférico devuelve al CPU en lecturas.
	output logic [31:0] rdata_o,

	// Línea serial de entrada.
	input  logic        uart_rx_i,

	// Línea serial de salida.
	output logic        uart_tx_o
);

	// Pulso de un ciclo que inicia una transmisión.
	logic tx_start_pulse;

	// Indica que el transmisor está libre.
	logic tx_ready;

	// Dato recibido por el módulo RX.
	logic [7:0] rx_data;

	// Bandera que indica que hay un byte recibido pendiente de lectura.
	logic       rx_ready;

	// Bandera de error de recepción.
	logic       rx_error;

	// Pulso para limpiar rx_ready cuando el CPU lee RXDATA.
	logic       clear_ready;

	// Registro donde se guarda el byte que se va a transmitir.
	logic [7:0] tx_data_reg;

	// El transmisor se encarga de armar la trama UART de salida.
	uart_tx u_tx (
		.clk_i        (clk_i),
		.rst_i        (rst_i),
		.tx_start_i   (tx_start_pulse),
		.tx_data_i    (tx_data_reg),
		.uart_tx_o    (uart_tx_o),
		.tx_ready_o   (tx_ready)
	);

	// El receptor toma la línea serial, reconstruye el byte y levanta rx_ready.
	uart_rx u_rx (
		.clk_i          (clk_i),
		.rst_i          (rst_i),
		.uart_rx_i      (uart_rx_i),
		.clear_ready_i  (clear_ready),
		.rx_data_o      (rx_data),
		.rx_ready_o     (rx_ready),
		.rx_error_o     (rx_error)
	);

	// Decodificación de escritura a CTRL/STATUS.
	logic wr_ctrl;

	// Decodificación de escritura a TXDATA.
	logic wr_txdata;

	// Registro que genera el pulso real de inicio para TX.
	logic tx_start_reg;

	assign wr_ctrl   = cs_i && we_i && (local_addr_i == 13'h000);
	assign wr_txdata = cs_i && we_i && (local_addr_i == 13'h004);

	always_ff @(posedge clk_i or negedge rst_i) begin
		if (!rst_i) begin
			tx_data_reg  <= 8'h00;
			tx_start_reg <= 1'b0;
		end else begin
			// Por defecto el inicio de transmisión dura solo un ciclo.
			tx_start_reg <= 1'b0;

			// Escribir TXDATA carga el byte y arranca la transmisión si TX está libre.
			// El pulso queda registrado para que uart_tx vea el dato ya actualizado.
			if (wr_txdata && tx_ready) begin
				tx_data_reg  <= wdata_i[7:0];
				tx_start_reg <= 1'b1;
			end

			// También se permite iniciar desde CTRL/STATUS[2].
			// En ese caso se transmite el byte que ya estaba cargado en tx_data_reg.
			else if (wr_ctrl && wdata_i[2] && tx_ready) begin
				tx_start_reg <= 1'b1;
			end
		end
	end

	assign tx_start_pulse = tx_start_reg;

	// Leer RXDATA limpia la bandera de dato recibido.
	assign clear_ready = cs_i && !we_i && (local_addr_i == 13'h008);

	always_comb begin
		// Valor por defecto para lecturas fuera del periférico o registros reservados.
		rdata_o = 32'd0;

		if (cs_i && !we_i) begin
			case (local_addr_i)
				// CTRL/STATUS devuelve las banderas principales.
				13'h000: rdata_o = {29'd0, 1'b0, rx_ready, tx_ready};

				// TXDATA es solo de escritura, por eso leerlo devuelve cero.
				13'h004: rdata_o = 32'd0;

				// RXDATA devuelve el último byte recibido en los bits bajos.
				13'h008: rdata_o = {24'd0, rx_data};

				default: rdata_o = 32'd0;
			endcase
		end
	end

endmodule
