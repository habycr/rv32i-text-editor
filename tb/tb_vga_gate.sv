`timescale 1ns/1ps
// ============================================================================
// tb_vga_gate.sv  --  Testbench GATE-LEVEL para el controlador VGA (vga_controller)
// Proyecto CE 3201 — DE1-SoC (Cyclone V 5CSEMA5F31C6)
//
// QUÉ ES UN TESTBENCH GATE-LEVEL
//   Aquí 'vga_controller' es el NETLIST POST-SÍNTESIS (compuertas + memorias
//   M10K + primitivas Cyclone V) con timing real anotado por SDF. Verifica que
//   el VGA sigue generando sincronismo y color correctos después de sintetizar.
//
//   El netlist está APLANADO -> este TB verifica SOLO por los PUERTOS:
//     - hsync_o / vsync_o : cadencia del estándar 640x480@60 (lo más fiable
//                           en gate-level: viene de contadores que se preservan)
//     - r_o/g_o/b_o       : que el color salga NO-negro al pintar una celda con
//                           fondo gris (atributo bg=7), independiente de la fuente.
//
// CÓMO GENERAR EL NETLIST DEL VGA (en Quartus, una sola vez)
//   1. Settings -> General: poner 'vga_controller' como Top-Level Entity.
//   2. Compilar (Ctrl+L). Genera en simulation/modelsim/:
//        vga_controller.svo    (netlist gate-level)
//        vga_controller_v.sdo  (retardos SDF)
//   3. Restaurar 'microcontroller' como Top-Level Entity.
//
// CÓMO CORRER EN MODELSIM (gate-level)
//   vlib work
//   vlog -work work $QUARTUS/eda/sim_lib/cyclonev_atoms.v
//   vlog -work work $QUARTUS/eda/sim_lib/altera_mf.v
//   vlog -work work $QUARTUS/eda/sim_lib/altera_primitives.v
//   vlog -sv simulation/modelsim/vga_controller.svo
//   vlog -sv tb/tb_vga_gate.sv
//   vsim -t ps -sdftyp u_dut=simulation/modelsim/vga_controller_v.sdo tb_vga_gate
//   run -all
//
//   NOTA: este TB recorre un CUADRO completo (525 líneas) para capturar el
//   pulso de vsync, así que la corrida tarda (~16 ms de tiempo simulado).
// ============================================================================

module tb_vga_gate;

    // ------------------------------------------------------------------------
    // Reloj de píxel 25 MHz (periodo 40 ns). En el diseño real clk_sys = clk_25,
    // por eso ambos puertos de reloj del controlador se manejan con el mismo clk.
    // ------------------------------------------------------------------------
    logic clk25 = 1'b0;
    logic rst_n = 1'b0;
    always #20 clk25 = ~clk25;      // 40 ns -> 25 MHz

    // ------------------------------------------------------------------------
    // Interfaz del controlador VGA
    // ------------------------------------------------------------------------
    logic [31:0] addr;
    logic [31:0] wdata;
    logic        we;
    logic        cs_vga;
    logic [31:0] rdata;
    logic        hsync, vsync;
    logic [3:0]  r, g, b;

    // DUT: el controlador VGA. En gate-level esta instancia ES vga_controller.svo.
    vga_controller u_dut (
        .clk_50_i (clk25),          // puerto de escritura (en HW = clk_sys = clk_25)
        .clk_25_i (clk25),          // reloj de píxel
        .rst_i    (rst_n),
        .addr_i   (addr),
        .wdata_i  (wdata),
        .we_i     (we),
        .cs_vga_i (cs_vga),
        .rdata_o  (rdata),
        .hsync_o  (hsync),
        .vsync_o  (vsync),
        .r_o      (r),
        .g_o      (g),
        .b_o      (b)
    );

    // ------------------------------------------------------------------------
    // (Opcional) Anotación SDF dentro del TB (alternativa a -sdftyp de vsim).
    // ------------------------------------------------------------------------
    // initial begin
    //     $sdf_annotate("simulation/modelsim/vga_controller_v.sdo", u_dut);
    // end

    // ------------------------------------------------------------------------
    // Parámetros del estándar 640x480@60 (deben coincidir con vga_timing_gen)
    // ------------------------------------------------------------------------
    localparam int H_TOTAL = 800;
    localparam int H_SYNC  = 96;    // ancho del pulso hsync (en píxeles)

    // Dirección de la celda (0,0) del buffer de texto y atributo con fondo gris.
    // Formato de celda: [15:12]=bg, [11:8]=fg, [7:0]=ascii.
    // bg=7 (gris) garantiza color NO-negro aunque la fuente no tenga glifo.
    localparam [31:0] VGA_BUF   = 32'h0001_1000;
    localparam [31:0] CELL_GRAY = 32'h0000_7041;  // 'A', fg=0, bg=7

    // ------------------------------------------------------------------------
    // Medición de la cadencia de hsync (entre dos flancos de bajada)
    // ------------------------------------------------------------------------
    logic prev_hs;
    int   period_cnt, low_cnt;
    int   meas_period, meas_low;
    bit   measuring, hs_measured;

    // ------------------------------------------------------------------------
    // Detección de vsync y de color no-negro
    // ------------------------------------------------------------------------
    logic prev_vs;
    bit   vsync_seen;
    bit   rgb_nonzero;

    always @(posedge clk25) begin
        if (!rst_n) begin
            prev_hs     <= 1'b1;
            prev_vs     <= 1'b1;
            period_cnt  <= 0;
            low_cnt     <= 0;
            measuring   <= 1'b0;
            hs_measured <= 1'b0;
            vsync_seen  <= 1'b0;
            rgb_nonzero <= 1'b0;
        end else begin
            prev_hs <= hsync;
            prev_vs <= vsync;

            // ----- Medición de hsync (primer periodo completo) -----
            if (!hs_measured) begin
                if (measuring) begin
                    period_cnt <= period_cnt + 1;
                    if (!hsync) low_cnt <= low_cnt + 1;
                    // siguiente flanco de bajada => fin del periodo
                    if (prev_hs && !hsync) begin
                        meas_period <= period_cnt + 1;
                        meas_low    <= low_cnt;
                        hs_measured <= 1'b1;
                    end
                end else if (prev_hs && !hsync) begin
                    // primer flanco de bajada: arrancar medición
                    measuring  <= 1'b1;
                    period_cnt <= 0;
                    low_cnt    <= 1;          // este ciclo ya está bajo
                end
            end

            // ----- vsync: detectar un flanco de bajada (1 por cuadro) -----
            if (prev_vs && !vsync)
                vsync_seen <= 1'b1;

            // ----- color: cualquier RGB no-negro durante el barrido -----
            if ((r != 4'd0) || (g != 4'd0) || (b != 4'd0))
                rgb_nonzero <= 1'b1;
        end
    end

    // ------------------------------------------------------------------------
    // Estímulo y evaluación
    // ------------------------------------------------------------------------
    initial begin
        $display("=== tb_vga_gate: simulacion GATE-LEVEL de vga_controller ===");

        // Valores iniciales del bus
        addr   = '0;
        wdata  = '0;
        we     = 1'b0;
        cs_vga = 1'b0;

        // Reset activo
        rst_n = 1'b0;

        // Escribir la celda (0,0) con fondo gris MIENTRAS está en reset
        // (la escritura al buffer no depende del reset; los contadores de
        //  barrido sí, así que aún no se escanea nada).
        @(negedge clk25);
        addr   = VGA_BUF;
        wdata  = CELL_GRAY;
        cs_vga = 1'b1;
        we     = 1'b1;
        @(negedge clk25);
        we     = 1'b0;
        cs_vga = 1'b0;

        // Liberar reset: comienza el barrido
        repeat (2) @(posedge clk25);
        rst_n = 1'b1;

        // Recorrer un cuadro completo + margen (525 lineas * 800 px).
        repeat (H_TOTAL * 530) @(posedge clk25);

        // -------- Evaluación --------
        $display("--- Resultado ---");
        $display("hsync: periodo medido = %0d (esperado %0d), pulso bajo = %0d (esperado %0d)",
                 meas_period, H_TOTAL, meas_low, H_SYNC);

        // Tolerancia +/-1 por borde de medición
        if (!hs_measured)
            $display("FALLO: nunca se midio un periodo de hsync.");
        else if ((meas_period < H_TOTAL-1) || (meas_period > H_TOTAL+1))
            $display("FALLO: periodo de hsync fuera de rango.");
        else if ((meas_low < H_SYNC-1) || (meas_low > H_SYNC+1))
            $display("FALLO: ancho del pulso hsync fuera de rango.");
        else
            $display("OK: hsync con cadencia 640x480@60 correcta.");

        if (vsync_seen)
            $display("OK: vsync genero su pulso (un cuadro completo barrido).");
        else
            $display("FALLO: nunca se detecto el pulso de vsync.");

        if (rgb_nonzero)
            $display("OK: el RGB salio no-negro al pintar la celda con fondo gris.");
        else
            $display("FALLO: el RGB nunca salio del negro (ruta buffer->paleta->RGB).");

        $display("=== Fin tb_vga_gate ===");
        $finish;
    end

    // Watchdog generoso (el cuadro completo tarda ~16 ms simulados).
    initial begin
        #25_000_000;   // 25 ms
        $display("FALLO: watchdog -- la simulacion no termino a tiempo.");
        $finish;
    end

endmodule
