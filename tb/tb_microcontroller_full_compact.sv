`timescale 1ns/1ps

// =============================================================================
// tb_microcontroller_full_compact.sv
// Testbench integral compacto para microcontroller + editor.
// Prueba: reset, ROM, VGA, PS/2, letras, enter, backspace, flechas,
// modos INSERT/COMMAND, :q, :r, :w inicial, UART RX/TX y stall de lw.
// NO agregar al .qsf. Usar solo en ModelSim/Questa con +define+SIMULATION.
// =============================================================================

module tb_microcontroller_final;

    parameter string ROM_FILE = "rom.hex";

    localparam int CLK_PERIOD_NS = 20;
    localparam int VGA_CELLS     = 1920;
    localparam int STATUS_CELL   = 1840;

    localparam logic [31:0] VGA_BUF_BASE = 32'h0001_1000;
    localparam int UART_BIT_NS           = 8680;
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

    initial begin
        for (i = 0; i < VGA_CELLS; i = i + 1)
            vga_ascii[i] = 8'h00;

        vga_ctrl_writes = 0;
        stall_holds     = 0;
        stall_wbs       = 0;
        saw_stall_hold  = 1'b0;
        saw_stall_wb    = 1'b0;
    end

    function string ch(input logic [7:0] c);
        begin
            ch = (c >= 8'h20 && c <= 8'h7E) ? {c} : ".";
        end
    endfunction

    always @(posedge CLOCK_50) begin
        if (rst_n) begin
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
                @(posedge CLOCK_50);
                ok = 1'b1;
                for (k = 0; k < exp.len(); k = k + 1)
                    if (vga_ascii[base+k] !== exp[k])
                        ok = 1'b0;

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

    task automatic wait_lw_stall(input int timeout);
        int cyc;
        begin
            for (cyc = 0; cyc < timeout; cyc = cyc + 1) begin
                @(posedge CLOCK_50);
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
                @(posedge CLOCK_50);
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
        begin
            ps2_make(8'h76);
            wait_vga(STATUS_CELL, "COMMAND", 2_000_000);
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
                $display("[FAIL] UART %s: esperado=%02h recibido=%02h", label_text, exp, got);
                $fatal;
            end
            $display("[PASS] UART %s = 0x%02h", label_text, got);
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

    initial begin
        #300_000_000;
        $display("[FAIL] Timeout global");
        $fatal;
    end

    integer ctrl_before;

    initial begin
        $display("====================================================");
        $display("TB INTEGRAL COMPACTO: MICROCONTROLLER + EDITOR");
        $display("ROM_FILE=%s", ROM_FILE);
        $display("====================================================");

        apply_reset();

        wait_vga(STATUS_CELL, "INSERT", 2_000_000);
        wait_lw_stall(200_000);

        ps2_make(8'h1C); // a
        wait_vga(0, "a", 2_000_000);

        ps2_make(8'h32); // b
        wait_vga(0, "ab", 2_000_000);

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

        ps2_make(8'h66); // backspace
        wait_vga(0, "a ", 2_000_000);

        ps2_make(8'h32); // b otra vez
        wait_vga(0, "ab", 2_000_000);

        ps2_make(8'h5A); // enter
        ps2_make(8'h21); // c
        wait_vga(80, "c", 2_000_000);

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

        ensure_command_mode();
        ps2_colon();
        ps2_make(8'h2D); // r

        expect_uart(8'h05, "ENQ de :r");
        uart_send_to_dut(8'h01); // SOH
        uart_send_to_dut(8'h78); // x
        uart_send_to_dut(8'h79); // y
        uart_send_to_dut(8'h04); // EOT

        wait_vga(0, "xy", 4_000_000);
        $display("[PASS] Comando :r cargó datos por UART");

        ensure_command_mode();
        ps2_colon();
        ps2_make(8'h1D); // w

        expect_uart(8'h01, "SOH de :w");
        expect_uart(8'h78, "primer byte guardado 'x'");
        expect_uart(8'h79, "segundo byte guardado 'y'");
        $display("[PASS] Inicio de :w verificado por UART");

        $display("====================================================");
        $display("[PASS] TESTBENCH INTEGRAL COMPACTO COMPLETADO");
        $display("Stalls lw observados: holds=%0d writebacks=%0d", stall_holds, stall_wbs);
        $display("VGA_CTRL writes observados: %0d", vga_ctrl_writes);
        $display("====================================================");
        $finish;
    end

endmodule
