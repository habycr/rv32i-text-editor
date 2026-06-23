`timescale 1ns/1ps

// Envoltorio del PLL usado para obtener el reloj del timer.
// En hardware instancia el IP timer_pll de Intel FPGA.
// En simulación, cuando se compila con SIMULATION, reemplaza el PLL por
// un divisor sencillo para que ModelSim también tenga un reloj de 25 MHz.

module timer_pll_wrapper (
	input  logic refclk_i,
	input  logic rst_i,
	output logic timer_clk_o,
	output logic locked_o
);

`ifdef SIMULATION

	logic       clk_div2;
	logic [3:0] lock_cnt;

	always_ff @(posedge refclk_i or negedge rst_i) begin
		if (!rst_i) begin
			clk_div2 <= 1'b0;
			lock_cnt <= 4'd0;
			locked_o <= 1'b0;
		end else begin
			// Divide 50 MHz entre 2 para obtener 25 MHz.
			clk_div2 <= ~clk_div2;

			// Pequeño retardo de lock para simular que el PLL no bloquea
			// instantáneamente al salir de reset.
			if (lock_cnt != 4'hF)
				lock_cnt <= lock_cnt + 4'd1;

			if (lock_cnt >= 4'd4)
				locked_o <= 1'b1;
			else
				locked_o <= 1'b0;
		end
	end

	assign timer_clk_o = clk_div2;

`else

	timer_pll u_timer_pll (
		.refclk   (refclk_i),
		.rst      (~rst_i),
		.outclk_0 (timer_clk_o),
		.locked   (locked_o)
	);

`endif

endmodule