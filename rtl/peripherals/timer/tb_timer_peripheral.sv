// Testbench auto-verificador para el periférico timer.
// Usa parámetros reducidos para que la simulación avance rápido, pero mantiene
// la misma idea de funcionamiento: el prescaler genera ticks y el contador baja.

// La prueba revisa reset, escrituras ignoradas con cs_i en cero, DATA/COUNT,
// start, stop, clear, autoreload, bits reservados y el caso borde de iniciar en cero.

`timescale 1ns/1ps

module tb_timer_peripheral;

	// Parámetros usados para acelerar la simulación.
	localparam CLK_PERIOD    = 20;    // 20 ns → 50 MHz
	localparam TB_CLK_HZ     = 100;   // frecuencia ficticia para simulación
	localparam TB_TICK_HZ    = 10;    // → DIVISOR = 10 ciclos por tick
	localparam TB_TICK_CYCLES = TB_CLK_HZ / TB_TICK_HZ;  // = 10

	// Señales conectadas al módulo bajo prueba.
	logic        clk;
	logic        rst;
	logic        cs;
	logic        we;
	logic [12:0] local_addr;
	logic [31:0] wdata;
	logic [31:0] rdata;

	// Cuenta cuántas verificaciones fallaron.
	int fail_count = 0;

	// Instancia del timer con parámetros pequeños para simular más rápido.
	timer_peripheral #(
		.CLK_FREQ_HZ(TB_CLK_HZ),
		.TICK_HZ    (TB_TICK_HZ)
	) dut (
		.clk_i       (clk),
		.rst_i       (rst),
		.cs_i        (cs),
		.we_i        (we),
		.local_addr_i(local_addr),
		.wdata_i     (wdata),
		.rdata_o     (rdata)
	);

	// Reloj usado por el testbench.
	initial clk = 1'b0;
	always #(CLK_PERIOD/2) clk = ~clk;

	// Tarea auxiliar para escribir un registro del timer.
	task automatic bus_write(
		input logic [12:0] addr,
		input logic [31:0] data
	);
		@(negedge clk);
		cs         = 1'b1;
		we         = 1'b1;
		local_addr = addr;
		wdata      = data;
		@(posedge clk);
		#1;              // pequeño margen después del flanco
		cs         = 1'b0;
		we         = 1'b0;
		local_addr = 13'h000;
		wdata      = 32'd0;
	endtask

	// Tarea auxiliar para leer un registro del timer.
	task automatic bus_read(
		input  logic [12:0] addr,
		output logic [31:0] data
	);
		@(negedge clk);
		cs         = 1'b1;
		we         = 1'b0;
		local_addr = addr;
		wdata      = 32'd0;
		@(posedge clk);
		#1;
		data       = rdata;
		cs         = 1'b0;
		local_addr = 13'h000;
	endtask

	// Tarea auxiliar para comparar el resultado obtenido contra el esperado.
	task automatic check(
		input string  test_name,
		input logic [31:0] got,
		input logic [31:0] expected
	);
		if (got === expected) begin
			$display("  PASS | %-45s | got=0x%08h", test_name, got);
		end else begin
			$display("  FAIL | %-45s | got=0x%08h expected=0x%08h", test_name, got, expected);
			fail_count = fail_count + 1;
		end
	endtask

	// Espera una cantidad de ticks del prescaler.
	task automatic wait_ticks(input int n);
		repeat (n * TB_TICK_CYCLES) @(posedge clk);
		#1;
	endtask

	// Secuencia principal de pruebas.
	logic [31:0] rd;
	logic [31:0] rd2;

	initial begin
		// Estado inicial de las señales del bus.
		rst        = 1'b1;
		cs         = 1'b0;
		we         = 1'b0;
		local_addr = 13'h000;
		wdata      = 32'd0;

		// T1. Reset
		$display("");
		$display("=== T1: Reset ===");
		rst = 1'b0;
		@(posedge clk); #1;
		@(posedge clk); #1;
		rst = 1'b1;
		@(posedge clk); #1;

		// Revisar CTRL/STATUS después del reset.
		bus_read(13'h000, rd);
		check("T1: CTRL bit0 running=0 tras reset",        rd[0],    1'b0);
		check("T1: CTRL bit1 stop=0 (WO, siempre lee 0)", rd[1],    1'b0);
		check("T1: CTRL bit2 timeout=0 tras reset",        rd[2],    1'b0);
		check("T1: CTRL bit3 autoreload=0 tras reset",     rd[3],    1'b0);
		check("T1: CTRL bit4 clear=0 (WO, siempre lee 0)", rd[4],   1'b0);
		check("T1: CTRL bits[31:5] reservados = 0",        rd[31:5], 27'd0);

		// Revisar DATA/COUNT después del reset.
		bus_read(13'h004, rd);
		check("T1: DATA = 0 tras reset",                   rd,       32'd0);

		// T2. cs_i=0 ignora escrituras
		$display("");
		$display("=== T2: cs_i=0 ignora escrituras ===");

		// Probar una escritura a CTRL con cs=0.
		@(negedge clk);
		cs         = 1'b0;  // cs_i = 0 — NO debe procesar
		we         = 1'b1;
		local_addr = 13'h000;
		wdata      = 32'hFFFF_FFFF;
		@(posedge clk); #1;
		cs = 1'b0; we = 1'b0;

		// Probar una escritura a DATA con cs=0.
		@(negedge clk);
		cs         = 1'b0;
		we         = 1'b1;
		local_addr = 13'h004;
		wdata      = 32'hDEAD_BEEF;
		@(posedge clk); #1;
		cs = 1'b0; we = 1'b0;

		// Confirmar que las escrituras anteriores no cambiaron el estado.
		bus_read(13'h000, rd);
		check("T2: CTRL sin cambios tras escritura con cs=0", rd, 32'd0);
		bus_read(13'h004, rd);
		check("T2: DATA sin cambios tras escritura con cs=0", rd, 32'd0);

		// Confirmar que la lectura queda en cero cuando el periférico no está seleccionado.
		@(negedge clk);
		cs         = 1'b0;
		we         = 1'b0;
		local_addr = 13'h000;
		@(posedge clk); #1;
		check("T2: rdata_o=0 cuando cs=0", rdata, 32'd0);
		cs = 1'b0;

		// T3. Escritura de DATA
		$display("");
		$display("=== T3: Escritura de DATA ===");

		// Primero provocar timeout para verificar que DATA write lo limpia
		bus_write(13'h004, 32'd1);  // cargar 1
		bus_write(13'h000, 32'h0000_0001); // start=1
		wait_ticks(3);              // esperar timeout
		bus_read(13'h000, rd);
		// Ahora escribir un nuevo valor de DATA
		bus_write(13'h004, 32'd5);
		bus_read(13'h004, rd);
		check("T3: DATA lee 5 tras escritura", rd, 32'd5);
		bus_read(13'h000, rd);
		check("T3: timeout limpiado por escritura DATA", rd[2], 1'b0);
		check("T3: running no cambia por escritura DATA", rd[0], 1'b0); // estaba detenido por T5

		// T4. Start y cuenta regresiva
		$display("");
		$display("=== T4: Start y cuenta regresiva ===");

		// Cargar un valor inicial
		bus_write(13'h004, 32'd10);
		// Arrancar el timer (start=1)
		bus_write(13'h000, 32'h0000_0001);

		// Verificar que running = 1 inmediatamente
		bus_read(13'h000, rd);
		check("T4: running=1 tras start", rd[0], 1'b1);

		// Esperar 2 ticks y verificar que el contador decrementó
		wait_ticks(2);
		bus_read(13'h004, rd);
		// Después de 2 ticks: 10 → 9 → 8
		check("T4: count decrementa (debe ser 8 tras 2 ticks)", rd, 32'd8);

		// Verificar que running sigue en 1
		bus_read(13'h000, rd);
		check("T4: running=1 mientras cuenta", rd[0], 1'b1);
		check("T4: timeout=0 mientras cuenta", rd[2], 1'b0);

		// T5. Timeout sin autoreload
		$display("");
		$display("=== T5: Timeout sin autoreload ===");

		// (Continuación del T4: count=8, running=1, autoreload=0)
		// Esperar suficientes ticks para llegar a timeout (8 + 1 = 9 ticks más)
		wait_ticks(9);

		bus_read(13'h000, rd);
		check("T5: timeout=1 tras llegar a cero",  rd[2], 1'b1);
		check("T5: running=0 sin autoreload",       rd[0], 1'b0);
		check("T5: stop lee 0 (WO)",                rd[1], 1'b0);
		check("T5: clear lee 0 (WO)",               rd[4], 1'b0);

		bus_read(13'h004, rd);
		check("T5: count=0 en timeout sin autoreload", rd, 32'd0);

		// T6. Comando clear
		$display("");
		$display("=== T6: Comando clear ===");

		// Cargar un valor de referencia para reload
		bus_write(13'h004, 32'd7);    // reload = 7, count = 7, timeout = 0

		// Forzar timeout: arrancar, esperar
		bus_write(13'h000, 32'h0000_0001);  // start=1
		wait_ticks(9);                       // timeout a count=0

		// Verificar timeout
		bus_read(13'h000, rd);
		check("T6: timeout=1 antes de clear", rd[2], 1'b1);
		check("T6: running=0 antes de clear", rd[0], 1'b0);

		// Enviar comando clear (bit 4)
		bus_write(13'h000, 32'h0000_0010);  // clear=1 (bit4)

		// Verificar resultado
		bus_read(13'h004, rd);
		check("T6: count recargado desde reload (7)", rd, 32'd7);
		bus_read(13'h000, rd);
		check("T6: timeout=0 tras clear",  rd[2], 1'b0);
		check("T6: clear bit lee 0 (WO)",  rd[4], 1'b0);

		// T7. Comando stop
		$display("");
		$display("=== T7: Comando stop ===");

		// Cargar y arrancar
		bus_write(13'h004, 32'd20);
		bus_write(13'h000, 32'h0000_0001);  // start=1

		wait_ticks(3);  // contar 3 ticks: 20→19→18→17
		bus_read(13'h004, rd);
		check("T7: count=17 tras 3 ticks desde 20", rd, 32'd17);

		// Enviar stop (bit 1)
		bus_write(13'h000, 32'h0000_0002);  // stop=1 (bit1)

		bus_read(13'h000, rd);
		check("T7: running=0 tras stop",   rd[0], 1'b0);
		check("T7: stop bit lee 0 (WO)",   rd[1], 1'b0);

		// Guardar valor del contador en el momento del stop
		bus_read(13'h004, rd);

		// Esperar varios ticks más y verificar que no cambia
		wait_ticks(5);
		bus_read(13'h004, rd2);
		check("T7: count no cambia tras stop", rd2, rd);

		// T8. Autoreload
		$display("");
		$display("=== T8: Autoreload ===");

		// Cargar valor pequeño
		bus_write(13'h004, 32'd3);
		// Arrancar con autoreload=1, start=1 (bits 3 y 0)
		bus_write(13'h000, 32'h0000_0009);  // autoreload=1 (bit3), start=1 (bit0)

		// Verificar autoreload y running activos
		bus_read(13'h000, rd);
		check("T8: autoreload=1",  rd[3], 1'b1);
		check("T8: running=1",     rd[0], 1'b1);

		// Esperar suficiente para que ocurra timeout y recarga (>4 ticks)
		wait_ticks(5);

		bus_read(13'h000, rd);
		check("T8: timeout=1 (primer ciclo completado)", rd[2], 1'b1);
		check("T8: running=1 después de autoreload",     rd[0], 1'b1);
		check("T8: autoreload=1 todavía",                rd[3], 1'b1);

		// El contador debe estar contando de nuevo desde 3 (o estar en 3-N)
		bus_read(13'h004, rd);
		// No sabemos exactamente en qué valor está, pero debe ser ≤ 3
		check("T8: count <= 3 tras autoreload", (rd <= 32'd3) ? 32'd1 : 32'd0, 32'd1);

		// Detener el timer
		bus_write(13'h000, 32'h0000_0002);  // stop=1

		// T9. Escritura de DATA mientras el timer corre
		$display("");
		$display("=== T9: Escritura DATA mientras corre ===");

		// Arrancar con un valor alto
		bus_write(13'h004, 32'd50);
		bus_write(13'h000, 32'h0000_0001);  // start=1

		wait_ticks(2);  // contar 2 ticks

		// Escribir nuevo valor de DATA mientras corre
		bus_write(13'h004, 32'd99);

		// Verificar: count actualizado, timeout limpiado, running sin cambio
		bus_read(13'h004, rd);
		check("T9: count actualizado a 99 inmediatamente", rd, 32'd99);

		bus_read(13'h000, rd);
		check("T9: timeout=0 tras DATA write",    rd[2], 1'b0);
		check("T9: running no cambia (sigue=1)",  rd[0], 1'b1);

		// El timer debe seguir contando desde 99
		wait_ticks(2);
		bus_read(13'h004, rd);
		check("T9: count continúa decrementando tras DATA write",
			  (rd < 32'd99) ? 32'd1 : 32'd0, 32'd1);

		// Detener
		bus_write(13'h000, 32'h0000_0002);  // stop=1

		// T10. Bits reservados
		$display("");
		$display("=== T10: Bits reservados ===");

		// Resetear el timer para estado conocido
		rst = 1'b0;
		@(posedge clk); #1;
		@(posedge clk); #1;
		rst = 1'b1;
		@(posedge clk); #1;

		// Escribir 0xFFFF_FFFF a CTRL activa start(bit0) Y stop(bit1) a la vez.
		// Por diseño STOP tiene prioridad sobre START (ver timer_counter:
		// "detiene inmediatamente"), así que el timer queda detenido → running=0.
		// bit 3 = autoreload (R/W) sí se actualiza a 1.
		// bit 4 = clear → recarga count desde reload (=0 tras reset).
		// bits[31:5] y bit2 son reservados/RO y deben ignorarse.
		bus_write(13'h000, 32'hFFFF_FFFF);

		bus_read(13'h000, rd);
		check("T10: bit0 running=0 (stop tiene prioridad sobre start)", rd[0], 1'b0);
		check("T10: bit1 stop siempre lee 0 (WO)",            rd[1], 1'b0);
		check("T10: bit2 timeout=0 (RO, no se puede escribir)", rd[2], 1'b0);
		check("T10: bit3 autoreload=1",                        rd[3], 1'b1);
		check("T10: bit4 clear siempre lee 0 (WO)",           rd[4], 1'b0);
		check("T10: bits[31:5] reservados = 0",                rd[31:5], 27'd0);

		// Detener para prueba T11
		bus_write(13'h000, 32'h0000_0002);  // stop=1

		// T11. Caso borde: contador = 0 al iniciar
		$display("");
		$display("=== T11: Caso borde — contador en cero ===");

		// Resetear para estado limpio
		rst = 1'b0;
		@(posedge clk); #1;
		@(posedge clk); #1;
		rst = 1'b1;
		@(posedge clk); #1;

		// Escribir DATA = 0
		bus_write(13'h004, 32'd0);
		bus_read(13'h004, rd);
		check("T11: DATA=0 tras escribir 0", rd, 32'd0);

		// Arrancar el timer
		bus_write(13'h000, 32'h0000_0001);  // start=1

		// Esperar 2 ticks: en el primer tick debe detectar count==0 y hacer timeout
		wait_ticks(2);

		bus_read(13'h000, rd);
		check("T11: timeout=1 cuando inicia con count=0", rd[2], 1'b1);
		check("T11: running=0 tras timeout con count=0",  rd[0], 1'b0);

		bus_read(13'h004, rd);
		check("T11: count=0 sin underflow (no es 0xFFFFFFFF)", rd, 32'd0);

		// RESULTADO FINAL
		$display("");
		$display("====================================================================");
		if (fail_count == 0)
			$display("==== RESULT: ALL TESTS PASSED ====");
		else
			$display("==== RESULT: %0d FAILED ====", fail_count);
		$display("====================================================================");
		$display("");

		$stop;
	end

	// Corte de seguridad para evitar que una simulación colgada quede corriendo.
	initial begin
		#100_000;
		$display("TIMEOUT: el testbench no terminó en 100 us");
		$stop;
	end

endmodule
