// Periférico timer visto desde el bus de datos.
// Este módulo decodifica los accesos a CTRL/STATUS y DATA/COUNT, conecta el
// prescaler con el contador y arma el dato que la CPU recibe en una lectura.

// Mapa local:
// 13'h000 -> CTRL/STATUS.
// 13'h004 -> DATA/COUNT.
// Las direcciones absolutas las resuelve el address_translator antes de llegar aquí.
// El reset es activo en bajo.

module timer_peripheral #(
	parameter int CLK_FREQ_HZ = 50_000_000,  // frecuencia del reloj de entrada
	parameter int TICK_HZ     = 1000          // un tick = 1 ms con valores por defecto
)(
	input  logic        clk_i,
	input  logic        rst_i,
	input  logic        cs_i,            // chip select desde address_translator
	input  logic        we_i,            // write enable desde address_translator
	input  logic [12:0] local_addr_i,    // offset local desde address_translator
	input  logic [31:0] wdata_i,         // dato de escritura del CPU
	output logic [31:0] rdata_o          // dato de lectura hacia el CPU
);

	// Señales internas usadas para decodificar el acceso del bus.
	logic wr_ctrl;      // escritura a CTRL/STATUS (offset 13'h000)
	logic wr_data;      // escritura a DATA/COUNT  (offset 13'h004)

	// Bits individuales que se toman cuando la CPU escribe CTRL/STATUS.
	logic start_write;
	logic start_value;
	logic stop_cmd;
	logic autoreload_write;
	logic autoreload_value;
	logic clear_cmd;

	// Estado que entrega el contador.
	logic        running;
	logic        autoreload;
	logic        timeout;
	logic [31:0] count;

	// Pulso generado por el prescaler.
	logic tick;

	// Decodificación combinacional del bus.
	// Escritura de CTRL/STATUS: offset 13'h000
	assign wr_ctrl = cs_i && we_i && (local_addr_i == 13'h000);

	// Escritura de DATA/COUNT: offset 13'h004
	assign wr_data = cs_i && we_i && (local_addr_i == 13'h004);

	// Decodificación de bits individuales al escribir CTRL/STATUS:
	//   bit 0 = start  (R/W)
	//   bit 1 = stop   (WO, comando)
	//   bit 2 = timeout (RO, no se puede escribir)
	//   bit 3 = autoreload (R/W)
	//   bit 4 = clear  (WO, comando)
	assign start_write      = wr_ctrl;             // hay escritura a CTRL en este ciclo
	assign start_value      = wdata_i[0];          // bit0=1 ARRANCA (set-only); bit0=0 no detiene
	assign stop_cmd         = wr_ctrl && wdata_i[1];
	assign autoreload_write = wr_ctrl;             // autoreload es nivel R/W: bit3 se aplica en cada escritura
	assign autoreload_value = wdata_i[3];
	assign clear_cmd        = wr_ctrl && wdata_i[4];

	// Instancia del prescaler
	// El prescaler está habilitado siempre que el timer corra.
	// Cuando running = 0, el prescaler se frena y no emite ticks,
	// evitando cuentas fantasmas mientras el timer está detenido.
	timer_prescaler #(
		.CLK_FREQ_HZ(CLK_FREQ_HZ),
		.TICK_HZ    (TICK_HZ)
	) u_prescaler (
		.clk_i    (clk_i),
		.rst_i    (rst_i),
		.enable_i (running),   // activo solo cuando el timer corre
		.tick_o   (tick)
	);

	// Instancia del contador
	timer_counter u_counter (
		.clk_i             (clk_i),
		.rst_i             (rst_i),
		.tick_i            (tick),
		.start_write_i     (start_write),
		.start_value_i     (start_value),
		.stop_cmd_i        (stop_cmd),
		.clear_cmd_i       (clear_cmd),
		.autoreload_write_i(autoreload_write),
		.autoreload_value_i(autoreload_value),
		.data_write_i      (wr_data),
		.data_value_i      (wdata_i),
		.running_o         (running),
		.autoreload_o      (autoreload),
		.timeout_o         (timeout),
		.count_o           (count)
	);

	// Lectura de registros hacia la CPU. (combinacional)
	// Cuando cs_i = 0, rdata_o debe ser 32'd0.
	// Bits reservados siempre leen 0.
	// stop (bit 1) y clear (bit 4) son WO: siempre leen 0.
	// timeout (bit 2) es RO: refleja el estado interno.
	//
	// Formato CTRL/STATUS leído:
	//   [31:5] = 0  (reservado)
	//   [4]    = 0  (clear WO)
	//   [3]    = autoreload (R/W)
	//   [2]    = timeout (RO)
	//   [1]    = 0  (stop WO)
	//   [0]    = running/start (R/W)
	always_comb begin
		rdata_o = 32'd0;  // cs_i=0 devuelve cero; bits reservados = 0

		if (cs_i && !we_i) begin
			case (local_addr_i)
				13'h000: rdata_o = {27'd0, 1'b0, autoreload, timeout, 1'b0, running};
				13'h004: rdata_o = count;
				default: rdata_o = 32'd0;
			endcase
		end
	end

endmodule
