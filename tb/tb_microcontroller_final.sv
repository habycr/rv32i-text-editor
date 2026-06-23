`timescale 1ns/1ps

// =============================================================================
// tb_microcontroller_full_compact.sv
// Testbench integral compacto para microcontroller + editor. Versión final v7.
// Prueba: reset, ROM, VGA, PS/2, letras, enter, backspace, flechas,
// modos INSERT/COMMAND, :q, :r, :w inicial, UART RX/TX y stall de lw.
// TX se valida por escrituras al registro TXDATA; el UART serial ya se valida
// con tb_uart_peripheral.
// NO agregar al .qsf. Usar solo en ModelSim/Questa con +define+SIMULATION.
// =============================================================================

module tb_microcontroller_final;

    parameter string ROM_FILE = "rom.hex";

    // Compatibilidad con sim_final_integration.do antiguo.
    parameter int ENABLE_BACKSPACE_TEST  = 1;
    parameter int ENABLE_COMMAND_Q_TEST  = 1;
    parameter int ENABLE_UART_SAVE_TEST  = 1;
    parameter int DEBUG_VGA   = 0;
    parameter int DEBUG_PS2   = 0;
    parameter int DEBUG_BUS   = 0;
    parameter int DEBUG_STALL = 0;
    parameter int DEBUG_UART  = 0;

    localparam int CLK_PERIOD_NS = 20;      // CLOCK_50 físico de entrada
    localparam int VGA_CELLS     = 1920;
    localparam int STATUS_CELL   = 1840;

    localparam logic [31:0] VGA_BUF_BASE = 32'h0001_1000;
    localparam int UART_BIT_NS           = 8680;       // 115200 baud aprox.
    localparam int UART_TIMEOUT_NS       = 40_000_000;

    logic CLOCK_50;
    logic rst_n;

    tri1 PS2_CLK;
    tri1 PS2_DAT;
    logic ps2_clk_drive_low;
    logic ps2_dat_drive_low;

    logic UART_RXD;
    logic UART_TXD;

    logic VGA_HS, VGA_VS, VGA_CLK, VGA_BLANK_N, VGA_SYNC_N;
    logic [7:0] VGA_R, VGA_G, VGA_B;

    assign PS2_CLK = ps2_clk_drive_low ? 1'b0 : 1'bz;
    assign PS2_DAT = ps2_dat_drive_low ? 1'b0 : 1'bz;

    microcontroller #(
        .ROM_INIT_FILE(ROM_FILE)
    ) dut (
        .CLOCK_50    (CLOCK_50),
        .rst_n       (rst_n),
        .PS2_CLK     (PS2_CLK),
        .PS2_DAT     (PS2_DAT),
        .UART_RXD    (UART_RXD),
        .UART_TXD    (UART_TXD),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_R       (VGA_R),
        .VGA_G       (VGA_G),
        .VGA_B       (VGA_B),
        .VGA_CLK     (VGA_CLK),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N)
    );

    initial begin
        CLOCK_50 = 1'b0;
        forever #(CLK_PERIOD_NS/2) CLOCK_50 = ~CLOCK_50;
    end

    logic [7:0] vga_ascii [0:VGA_CELLS-1];

    integer i;
    integer vga_cell_idx;
    integer vga_ctrl_writes;

    integer stall_holds;
    integer stall_wbs;
    bit saw_stall_hold;
    bit saw_stall_wb;

    // Observador de escrituras UART desde el bus del SoC.
    integer uart_tx_write_count;
    logic [7:0] uart_tx_bytes [0:63];

    initial begin
        for (i = 0; i < VGA_CELLS; i = i + 1)
            vga_ascii[i] = 8'h00;

        vga_ctrl_writes     = 0;
        stall_holds         = 0;
        stall_wbs           = 0;
        saw_stall_hold      = 1'b0;
        saw_stall_wb        = 1'b0;
        uart_tx_write_count = 0;
    end

    function string ch(input logic [7:0] c);
        begin
            ch = (c >= 8'h20 && c <= 8'h7E) ? {c} : ".";
        end
    endfunction

    // -------------------------------------------------------------------------
    // Observador del dominio del sistema.
    //
    // Después del cierre de timing, CPU/ROM/RAM/bus/periféricos corren con
    // dut.clk_sys = 25 MHz, no con CLOCK_50.
    //
    // Por eso este bloque debe muestrear en posedge dut.clk_sys.
    // Si se usa CLOCK_50, una escritura de bus de 40 ns se observa dos veces.
    // -------------------------------------------------------------------------
    always @(posedge dut.clk_sys) begin
        if (dut.sys_rst_n) begin
            if (dut.prog_addr > 32'h0000_1FFF) begin
                $display("[FAIL] PC fuera de ROM: PC=%08h instr=%08h data_addr=%08h",
                         dut.prog_addr, dut.prog_in, dut.data_addr);
                $fatal;
            end

            if (dut.bus_we && dut.cs_vga_buffer) begin
                vga_cell_idx = (dut.data_addr - VGA_BUF_BASE) >> 2;
                if (vga_cell_idx >= 0 && vga_cell_idx < VGA_CELLS)
                    vga_ascii[vga_cell_idx] = dut.data_out[7:0];
            end

            if (dut.bus_we && dut.cs_vga_ctrl)
                vga_ctrl_writes <= vga_ctrl_writes + 1;

            // UART TXDATA está en offset local 0x004.
            // Se cuenta una sola vez por ciclo real del bus del sistema.
            if (dut.bus_we && dut.cs_uart && dut.local_addr == 13'h004) begin
                if (uart_tx_write_count < 64)
                    uart_tx_bytes[uart_tx_write_count] <= dut.data_out[7:0];

                uart_tx_write_count <= uart_tx_write_count + 1;

                if (DEBUG_UART != 0) begin
                    $display("[%0t] UART TXDATA write #%0d byte=0x%02h",
                             $time, uart_tx_write_count, dut.data_out[7:0]);
                end
            end

            if (dut.u_cpu.is_load && !dut.u_cpu.pc_en && !dut.u_cpu.reg_write_eff) begin
                stall_holds    <= stall_holds + 1;
                saw_stall_hold <= 1'b1;
            end

            if (dut.u_cpu.is_load && dut.u_cpu.pc_en && dut.u_cpu.reg_write_eff && saw_stall_hold) begin
                stall_wbs    <= stall_wbs + 1;
                saw_stall_wb <= 1'b1;
            end
        end
    end

    task automatic dump_vga(input int base, input int n);
        int k;
        string s;
        begin
            s = "";
            for (k = 0; k < n; k = k + 1)
                s = {s, ch(vga_ascii[base+k])};

            $display("VGA[%0d..%0d]=\"%s\"", base, base+n-1, s);
        end
    endtask

    task automatic wait_vga(input int base, input string exp, input int timeout);
        int cyc, k;
        bit ok;
        begin
            for (cyc = 0; cyc < timeout; cyc = cyc + 1) begin
                @(posedge dut.clk_sys);

                ok = 1'b1;
                for (k = 0; k < exp.len(); k = k + 1) begin
                    if (vga_ascii[base+k] !== exp[k])
                        ok = 1'b0;
                end

                if (ok) begin
                    $display("[PASS] VGA[%0d] contiene \"%s\"", base, exp);
                    return;
                end
            end

            $display("[FAIL] Timeout esperando VGA[%0d]=\"%s\"", base, exp);
            dump_vga(base, exp.len());
            $fatal;
        end
    endtask

    // Igual que wait_vga, pero no termina la simulación si no encuentra el texto.
    // Se usa para hacer ensure_command_mode más robusto después de comandos como :q.
    task automatic try_wait_vga(
        input int base,
        input string exp,
        input int timeout,
        output bit found
    );
        int cyc, k;
        bit ok;
        begin
            found = 1'b0;

            for (cyc = 0; cyc < timeout; cyc = cyc + 1) begin
                @(posedge dut.clk_sys);

                ok = 1'b1;
                for (k = 0; k < exp.len(); k = k + 1) begin
                    if (vga_ascii[base+k] !== exp[k])
                        ok = 1'b0;
                end

                if (ok) begin
                    found = 1'b1;
                    return;
                end
            end
        end
    endtask

    task automatic settle_editor(input int cycles);
        begin
            repeat (cycles) @(posedge dut.clk_sys);
        end
    endtask

    task automatic wait_lw_stall(input int timeout);
        int cyc;
        begin
            for (cyc = 0; cyc < timeout; cyc = cyc + 1) begin
                @(posedge dut.clk_sys);

                if (saw_stall_hold && saw_stall_wb && stall_holds > 0 && stall_wbs > 0) begin
                    $display("[PASS] Stall lw observado: holds=%0d writebacks=%0d",
                             stall_holds, stall_wbs);
                    return;
                end
            end

            $display("[FAIL] No se observó stall completo de lw");
            $fatal;
        end
    endtask

    task automatic wait_vga_ctrl_event(input string label_text, input int old_count);
        int cyc;
        begin
            for (cyc = 0; cyc < 200_000; cyc = cyc + 1) begin
                @(posedge dut.clk_sys);

                if (vga_ctrl_writes > old_count) begin
                    $display("[PASS] Cursor/VGA_CTRL actualizado por %s", label_text);
                    return;
                end
            end

            $display("[FAIL] No hubo actualización de cursor/VGA_CTRL por %s", label_text);
            $fatal;
        end
    endtask

    task automatic apply_reset;
        begin
            // Limpiar observadores del testbench antes de cada fase.
            for (i = 0; i < VGA_CELLS; i = i + 1)
                vga_ascii[i] = 8'h00;

            vga_ctrl_writes     = 0;
            stall_holds         = 0;
            stall_wbs           = 0;
            saw_stall_hold      = 1'b0;
            saw_stall_wb        = 1'b0;
            uart_tx_write_count = 0;

            for (i = 0; i < 64; i = i + 1)
                uart_tx_bytes[i] = 8'h00;

            UART_RXD = 1'b1;
            ps2_clk_drive_low = 1'b0;
            ps2_dat_drive_low = 1'b0;

            rst_n = 1'b0;
            repeat (10) @(posedge CLOCK_50);

            rst_n = 1'b1;
            repeat (20) @(posedge CLOCK_50);

            $display("[INFO] Reset liberado");
        end
    endtask

    task automatic ps2_clk_pulse;
        begin
            #(15_000);
            ps2_clk_drive_low = 1'b1;
            #(30_000);
            ps2_clk_drive_low = 1'b0;
            #(30_000);
        end
    endtask

    task automatic ps2_bit(input logic b);
        begin
            ps2_dat_drive_low = (b == 1'b0);
            ps2_clk_pulse();
        end
    endtask

    task automatic ps2_send(input logic [7:0] data);
        logic parity_bit;
        int k;
        begin
            parity_bit = ~(^data);

            ps2_clk_drive_low = 1'b0;
            ps2_dat_drive_low = 1'b0;
            #(50_000);

            ps2_bit(1'b0);

            for (k = 0; k < 8; k = k + 1)
                ps2_bit(data[k]);

            ps2_bit(parity_bit);
            ps2_bit(1'b1);

            ps2_dat_drive_low = 1'b0;
            #(180_000);
        end
    endtask

    task automatic ps2_make(input logic [7:0] sc);
        begin
            ps2_send(sc);
        end
    endtask

    task automatic ps2_break(input logic [7:0] sc);
        begin
            ps2_send(8'hF0);
            ps2_send(sc);
        end
    endtask

    task automatic ps2_ext_make(input logic [7:0] sc);
        begin
            ps2_send(8'hE0);
            ps2_send(sc);
        end
    endtask

    task automatic ps2_colon;
        begin
            ps2_make(8'h12);
            ps2_make(8'h4C);
            ps2_break(8'h4C);
            ps2_break(8'h12);
        end
    endtask

    task automatic ensure_command_mode;
        bit ok;
        begin
            // Dar tiempo al firmware para terminar comandos previos,
            // especialmente :q.
            settle_editor(50_000);

            // Si ya estamos en COMMAND, no enviar ESC.
            try_wait_vga(STATUS_CELL, "COMMAND", 1_000, ok);
            if (ok) begin
                $display("[PASS] Modo COMMAND ya activo");
                return;
            end

            ps2_make(8'h76); // ESC
            try_wait_vga(STATUS_CELL, "COMMAND", 2_000_000, ok);
            if (ok) begin
                $display("[PASS] Entró a modo COMMAND");
                return;
            end

            // Reintento: útil si el primer ESC cayó mientras el editor limpiaba.
            settle_editor(50_000);
            ps2_make(8'h76); // ESC
            try_wait_vga(STATUS_CELL, "COMMAND", 2_000_000, ok);
            if (ok) begin
                $display("[PASS] Entró a modo COMMAND en reintento");
                return;
            end

            $display("[FAIL] No se pudo entrar a modo COMMAND");
            dump_vga(STATUS_CELL, 8);
            $fatal;
        end
    endtask

    task automatic uart_recv(output logic [7:0] data);
        int k;
        time t0;
        begin
            data = 8'h00;
            t0 = $time;

            while (UART_TXD !== 1'b0) begin
                #(1000);

                if (($time - t0) > UART_TIMEOUT_NS) begin
                    $display("[FAIL] Timeout esperando UART TX start");
                    $fatal;
                end
            end

            #(UART_BIT_NS + UART_BIT_NS/2);

            for (k = 0; k < 8; k = k + 1) begin
                data[k] = UART_TXD;
                #(UART_BIT_NS);
            end

            if (UART_TXD !== 1'b1) begin
                $display("[FAIL] UART stop bit inválido");
                $fatal;
            end

            #(UART_BIT_NS);
        end
    endtask

    task automatic expect_uart(input logic [7:0] exp, input string label_text);
        logic [7:0] got;
        begin
            uart_recv(got);

            if (got !== exp) begin
                $display("[FAIL] UART %s: esperado=%02h recibido=%02h",
                         label_text, exp, got);
                $fatal;
            end

            $display("[PASS] UART %s = 0x%02h", label_text, got);
        end
    endtask

    task automatic check_uart_value(
        input logic [7:0] got,
        input logic [7:0] exp,
        input string label_text
    );
        begin
            if (got !== exp) begin
                $display("[FAIL] UART %s: esperado=%02h recibido=%02h",
                         label_text, exp, got);
                $fatal;
            end

            $display("[PASS] UART %s = 0x%02h", label_text, got);
        end
    endtask

    task automatic wait_uart_tx_writes(input int needed, input int timeout_cycles);
        int cyc;
        begin
            for (cyc = 0; cyc < timeout_cycles; cyc = cyc + 1) begin
                @(posedge dut.clk_sys);

                if (uart_tx_write_count >= needed) begin
                    $display("[PASS] UART TXDATA recibió %0d escritura(s)", needed);
                    return;
                end
            end

            $display("[FAIL] Timeout esperando %0d escritura(s) UART TXDATA. Vistas=%0d",
                     needed, uart_tx_write_count);
            $fatal;
        end
    endtask

    task automatic expect_uart_tx_write(
        input int index,
        input logic [7:0] exp,
        input string label_text
    );
        begin
            if (uart_tx_write_count <= index) begin
                $display("[FAIL] UART %s: no existe escritura índice %0d. Vistas=%0d",
                         label_text, index, uart_tx_write_count);
                $fatal;
            end

            if (uart_tx_bytes[index] !== exp) begin
                $display("[FAIL] UART %s: esperado=%02h recibido=%02h",
                         label_text, exp, uart_tx_bytes[index]);
                $fatal;
            end

            $display("[PASS] UART %s por TXDATA = 0x%02h",
                     label_text, uart_tx_bytes[index]);
        end
    endtask

    task automatic uart_send_to_dut(input logic [7:0] data);
        int k;
        begin
            UART_RXD = 1'b1;
            #(UART_BIT_NS);

            UART_RXD = 1'b0;
            #(UART_BIT_NS);

            for (k = 0; k < 8; k = k + 1) begin
                UART_RXD = data[k];
                #(UART_BIT_NS);
            end

            UART_RXD = 1'b1;
            #(UART_BIT_NS * 2);
        end
    endtask

    task automatic boot_editor(input string phase_name);
        begin
            $display("----------------------------------------------------");
            $display("[INFO] Inicio de fase: %s", phase_name);

            apply_reset();

            wait_vga(STATUS_CELL, "INSERT", 2_000_000);
            wait_lw_stall(200_000);
            settle_editor(50_000);
        end
    endtask

    initial begin
        #300_000_000;
        $display("[FAIL] Timeout global");
        $fatal;
    end

    integer ctrl_before;

    initial begin
        $display("====================================================");
        $display("TB INTEGRAL COMPACTO V7: MICROCONTROLLER + EDITOR");
        $display("ROM_FILE=%s", ROM_FILE);
        $display("====================================================");

        // ================================================================
        // FASE 1: editor local + PS/2 + VGA + comandos de modo + :q.
        // ================================================================
        boot_editor("PS/2, VGA, cursor y :q");

        ps2_make(8'h1C); // a
        wait_vga(0, "a", 2_000_000);

        ps2_make(8'h32); // b
        wait_vga(0, "ab", 2_000_000);

        ps2_make(8'h66); // backspace
        wait_vga(0, "a ", 2_000_000);

        ps2_make(8'h32); // b otra vez
        wait_vga(0, "ab", 2_000_000);

        ps2_make(8'h5A); // enter
        ps2_make(8'h21); // c
        wait_vga(80, "c", 2_000_000);

        ctrl_before = vga_ctrl_writes;
        ps2_ext_make(8'h6B); // left
        wait_vga_ctrl_event("flecha izquierda", ctrl_before);

        ctrl_before = vga_ctrl_writes;
        ps2_ext_make(8'h74); // right
        wait_vga_ctrl_event("flecha derecha", ctrl_before);

        ctrl_before = vga_ctrl_writes;
        ps2_ext_make(8'h75); // up
        wait_vga_ctrl_event("flecha arriba", ctrl_before);

        ctrl_before = vga_ctrl_writes;
        ps2_ext_make(8'h72); // down
        wait_vga_ctrl_event("flecha abajo", ctrl_before);

        ps2_make(8'h76); // ESC
        wait_vga(STATUS_CELL, "COMMAND", 2_000_000);

        ps2_make(8'h43); // i
        wait_vga(STATUS_CELL, "INSERT", 2_000_000);

        ensure_command_mode();

        ps2_colon();
        ps2_make(8'h15); // q

        wait_vga(0,  "  ", 4_000_000);
        wait_vga(80, " ",  4_000_000);

        $display("[PASS] Comando :q limpió el buffer");

        // ================================================================
        // FASE 2: UART save en sesión fresca.
        // ================================================================
        boot_editor("UART :w");

        ps2_make(8'h1C); // a
        wait_vga(0, "a", 2_000_000);

        ps2_make(8'h32); // b
        wait_vga(0, "ab", 2_000_000);

        ensure_command_mode();
        settle_editor(50_000);

        ps2_colon();
        settle_editor(20_000);

        // En el testbench integral NO se vuelve a decodificar UART_TXD por tiempo,
        // porque el módulo UART ya fue validado a nivel unitario.
        // Aquí se valida la integración:
        // firmware/parser -> bus -> registro UART TXDATA.
        ps2_make(8'h1D); // w

        wait_uart_tx_writes(3, 5_000_000);

        expect_uart_tx_write(0, 8'h01, "SOH de :w");
        expect_uart_tx_write(1, 8'h61, "primer byte guardado 'a'");
        expect_uart_tx_write(2, 8'h62, "segundo byte guardado 'b'");

        $display("[PASS] Inicio de :w verificado por escrituras a UART TXDATA");

        // ================================================================
        // FASE 3: UART load en sesión fresca.
        //
        // El firmware actual se está usando desde rom.hex, sin editor.s.
        // Ese firmware recibe SOH y luego necesita tiempo para preparar/limpiar
        // el área antes de leer el primer byte real. Como ahora el sistema corre
        // a 25 MHz, el TB no debe enviar SOH+x+y+EOT pegados sin pausa.
        // ================================================================
        boot_editor("UART :r");

        ensure_command_mode();
        settle_editor(50_000);

        ps2_colon();
        settle_editor(20_000);

        ps2_make(8'h2D); // r

        wait_uart_tx_writes(1, 5_000_000);
        expect_uart_tx_write(0, 8'h05, "ENQ de :r");

        uart_send_to_dut(8'h01); // SOH

        // Pausa clave:
        // permite que el firmware actual termine su preparación interna
        // antes de recibir el primer byte del archivo.
        settle_editor(100_000);

        uart_send_to_dut(8'h78); // x
        settle_editor(5_000);

        uart_send_to_dut(8'h79); // y
        settle_editor(5_000);

        uart_send_to_dut(8'h04); // EOT
        settle_editor(5_000);

        wait_vga(0, "xy", 4_000_000);

        $display("[PASS] Comando :r cargó datos por UART");

        $display("====================================================");
        $display("[PASS] TESTBENCH INTEGRAL COMPACTO V7 COMPLETADO");
        $display("Stalls lw observados: holds=%0d writebacks=%0d", stall_holds, stall_wbs);
        $display("VGA_CTRL writes observados: %0d", vga_ctrl_writes);
        $display("====================================================");

        $finish;
    end

endmodule