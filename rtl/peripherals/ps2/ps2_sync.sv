// Sincroniza las señales externas del puerto PS/2 con el reloj interno del sistema.
// Como ps2_clk_i y ps2_data_i vienen de fuera de la FPGA, primero pasan por
// flip-flops antes de usarse en la lógica interna.

// Además detecta el flanco descendente de ps2_clk, que es el momento donde
// el protocolo PS/2 toma cada bit.

// Bloque pequeño, pero necesario para usar PS/2 de forma estable.
module ps2_sync (
	// Reloj interno del sistema.
	input  logic clk_i,
	// Reset activo en bajo.
	input  logic rst_i,
	// Reloj PS/2 externo, viene directamente del conector.
	input  logic ps2_clk_i,
	// Línea de datos PS/2 externa.
	input  logic ps2_data_i,
	// Versión sincronizada de PS/2 CLK.
	output logic ps2_clk_sync_o,
	// Versión sincronizada de PS/2 DATA.
	output logic ps2_data_sync_o,
	// Pulso de un ciclo cuando se detecta un flanco descendente.
	output logic fall_edge_o       // 1 durante un ciclo al detectar flanco desc.
);

	// Tres etapas para sincronizar y comparar el reloj PS/2.
	logic clk_s1, clk_s2, clk_s3;
	always_ff @(posedge clk_i or negedge rst_i) begin
		if (!rst_i) begin
			clk_s1 <= 1'b1;
			clk_s2 <= 1'b1;
			clk_s3 <= 1'b1;
		end else begin
			clk_s1 <= ps2_clk_i;
			clk_s2 <= clk_s1;
			clk_s3 <= clk_s2;
		end
	end

	// Dos etapas para sincronizar la línea de datos.
	logic dat_s1, dat_s2;
	always_ff @(posedge clk_i or negedge rst_i) begin
		if (!rst_i) begin
			dat_s1 <= 1'b1;
			dat_s2 <= 1'b1;
		end else begin
			dat_s1 <= ps2_data_i;
			dat_s2 <= dat_s1;
		end
	end

	// Se entrega la señal ya estabilizada al resto del periférico.
	assign ps2_clk_sync_o  = clk_s2;
	assign ps2_data_sync_o = dat_s2;
	// Antes estaba en 1 y ahora está en 0: eso marca el flanco descendente.
	assign fall_edge_o     = clk_s3 & ~clk_s2;

endmodule
