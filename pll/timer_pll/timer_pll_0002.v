`timescale 1ns/10ps

// -----------------------------------------------------------------------------
// timer_pll_0002
// -----------------------------------------------------------------------------
// Núcleo interno de la IP del PLL. Este módulo instancia directamente el bloque
// altera_pll de Intel/Altera con los parámetros que configuró Quartus.
//
// La configuración importante para el proyecto es:
//   - reloj de entrada: 50 MHz
//   - cantidad de salidas usadas: 1
//   - outclk_0: 25 MHz
//   - fase: 0 ps
//   - duty cycle: 50 %
//
// Las demás salidas aparecen con frecuencia 0 MHz porque no se usan, pero
// Quartus mantiene los parámetros en el archivo generado de la IP.
// -----------------------------------------------------------------------------
module  timer_pll_0002(

	// Reloj de referencia del PLL. En la DE1-SoC normalmente viene de CLOCK_50.
	input wire refclk,

	// Reset del PLL. Reinicia el bloque de generación de reloj.
	input wire rst,

	// Salida principal del PLL. Está configurada a 25 MHz.
	output wire outclk_0,

	// Se activa cuando el PLL ya logró engancharse al reloj de referencia.
	output wire locked
);

	// Instancia del PLL primitivo de Intel/Altera.
	// Los parámetros definen la frecuencia de entrada, la salida generada,
	// la fase y el ciclo de trabajo. No se cambia lógica alrededor de la IP.
	altera_pll #(
		.fractional_vco_multiplier("false"),   // PLL entero; no usa multiplicación fraccional.
		.reference_clock_frequency("50.0 MHz"), // frecuencia esperada en refclk.
		.operation_mode("direct"),              // modo directo, sin realimentación externa.
		.number_of_clocks(1),                   // solo se expone una salida de reloj.
		.output_clock_frequency0("25.000000 MHz"), // frecuencia deseada para outclk_0.
		.phase_shift0("0 ps"),                  // sin desfase en la salida principal.
		.duty_cycle0(50),                       // ciclo de trabajo de 50 %.
		.output_clock_frequency1("0 MHz"),
		.phase_shift1("0 ps"),
		.duty_cycle1(50),
		.output_clock_frequency2("0 MHz"),
		.phase_shift2("0 ps"),
		.duty_cycle2(50),
		.output_clock_frequency3("0 MHz"),
		.phase_shift3("0 ps"),
		.duty_cycle3(50),
		.output_clock_frequency4("0 MHz"),
		.phase_shift4("0 ps"),
		.duty_cycle4(50),
		.output_clock_frequency5("0 MHz"),
		.phase_shift5("0 ps"),
		.duty_cycle5(50),
		.output_clock_frequency6("0 MHz"),
		.phase_shift6("0 ps"),
		.duty_cycle6(50),
		.output_clock_frequency7("0 MHz"),
		.phase_shift7("0 ps"),
		.duty_cycle7(50),
		.output_clock_frequency8("0 MHz"),
		.phase_shift8("0 ps"),
		.duty_cycle8(50),
		.output_clock_frequency9("0 MHz"),
		.phase_shift9("0 ps"),
		.duty_cycle9(50),
		.output_clock_frequency10("0 MHz"),
		.phase_shift10("0 ps"),
		.duty_cycle10(50),
		.output_clock_frequency11("0 MHz"),
		.phase_shift11("0 ps"),
		.duty_cycle11(50),
		.output_clock_frequency12("0 MHz"),
		.phase_shift12("0 ps"),
		.duty_cycle12(50),
		.output_clock_frequency13("0 MHz"),
		.phase_shift13("0 ps"),
		.duty_cycle13(50),
		.output_clock_frequency14("0 MHz"),
		.phase_shift14("0 ps"),
		.duty_cycle14(50),
		.output_clock_frequency15("0 MHz"),
		.phase_shift15("0 ps"),
		.duty_cycle15(50),
		.output_clock_frequency16("0 MHz"),
		.phase_shift16("0 ps"),
		.duty_cycle16(50),
		.output_clock_frequency17("0 MHz"),
		.phase_shift17("0 ps"),
		.duty_cycle17(50),
		.pll_type("General"),
		.pll_subtype("General")
	) altera_pll_i (
		// Reset conectado directamente al puerto externo del wrapper.
		.rst	(rst),

		// altera_pll maneja las salidas como vector; aquí solo se usa outclk_0.
		.outclk	({outclk_0}),

		// Señal de estabilidad del PLL. Puede usarse para liberar resets internos.
		.locked	(locked),

		// Puertos de realimentación no usados en esta configuración directa.
		.fboutclk	( ),
		.fbclk	(1'b0),

		// Reloj base que alimenta el PLL.
		.refclk	(refclk)
	);
endmodule
