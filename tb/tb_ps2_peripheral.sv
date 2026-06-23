// FILE: Branch_FSM_Control_UART_PS2/tb/tb_ps2_peripheral.sv
`timescale 1ns/1ps

module tb_ps2_peripheral;

    localparam CLK_PERIOD = 20;     // 50 MHz
    localparam PS2_HALF   = 1000;   // ns, reloj PS/2 rapido para simulacion

    logic        clk;
    logic        rst;

    logic        cs;
    logic        we;
    logic [12:0] local_addr;
    logic [31:0] wdata;
    logic [31:0] rdata;

    logic        ps2_clk_tb;
    logic        ps2_data_tb;
    logic        ps2_clk_o;
    logic        ps2_data_o;

    int fail_count = 0;

    ps2_peripheral dut (
        .clk_i        (clk),
        .rst_i        (rst),
        .cs_i         (cs),
        .we_i         (we),
        .local_addr_i (local_addr),
        .wdata_i      (wdata),
        .rdata_o      (rdata),
        .ps2_clk_i    (ps2_clk_tb),
        .ps2_data_i   (ps2_data_tb),
        .ps2_clk_o    (ps2_clk_o),
        .ps2_data_o   (ps2_data_o)
    );

    initial begin
        clk = 1'b0;
    end

    always #(CLK_PERIOD / 2) clk = ~clk;

    task automatic bus_read(
        input  logic [12:0] addr,
        output logic [31:0] data
    );
        @(posedge clk);
        cs         = 1'b1;
        we         = 1'b0;
        local_addr = addr;
        wdata      = 32'd0;

        @(posedge clk);
        data       = rdata;
        cs         = 1'b0;
        we         = 1'b0;

        @(posedge clk);
    endtask

    task automatic bus_write(
        input logic [12:0] addr,
        input logic [31:0] data
    );
        @(posedge clk);
        cs         = 1'b1;
        we         = 1'b1;
        local_addr = addr;
        wdata      = data;

        @(posedge clk);
        cs         = 1'b0;
        we         = 1'b0;

        @(posedge clk);
    endtask

    task automatic check32(
        input string       name,
        input logic [31:0] got,
        input logic [31:0] exp
    );
        if (got === exp) begin
            $display("PASS  %s: got=0x%08h", name, got);
        end else begin
            $display("FAIL  %s: got=0x%08h exp=0x%08h", name, got, exp);
            fail_count++;
        end
    endtask

    task automatic check1(
        input string name,
        input logic  got,
        input logic  exp
    );
        if (got === exp) begin
            $display("PASS  %s: got=%b", name, got);
        end else begin
            $display("FAIL  %s: got=%b exp=%b", name, got, exp);
            fail_count++;
        end
    endtask

    task automatic ps2_send_bit(input logic d);
        ps2_data_tb = d;
        #(PS2_HALF);

        ps2_clk_tb = 1'b0;
        #(PS2_HALF);

        ps2_clk_tb = 1'b1;
        #(PS2_HALF);
    endtask

    task automatic ps2_send_frame(input logic [7:0] data);
        logic parity;
        integer i;

        parity = ~(^data);  // paridad impar

        ps2_send_bit(1'b0);         // start
        for (i = 0; i < 8; i = i + 1) begin
            ps2_send_bit(data[i]);  // datos LSB-first
        end
        ps2_send_bit(parity);       // parity
        ps2_send_bit(1'b1);         // stop
    endtask

    task automatic ps2_send_bad_frame(input logic [7:0] data);
        logic bad_parity;
        integer i;

        bad_parity = ^data;  // paridad incorrecta a proposito

        ps2_send_bit(1'b0);             // start
        for (i = 0; i < 8; i = i + 1) begin
            ps2_send_bit(data[i]);      // datos LSB-first
        end
        ps2_send_bit(bad_parity);       // parity incorrecta
        ps2_send_bit(1'b1);             // stop
    endtask

    task automatic wait_rx_ready(output logic ok);
        integer i;
        logic [31:0] rd_local;

        ok = 1'b0;

        for (i = 0; i < 200000; i = i + 1) begin
            #(CLK_PERIOD);
            bus_read(13'h000, rd_local);

            if (rd_local[0]) begin
                ok = 1'b1;
                i  = 200000;
            end
        end
    endtask

    logic [31:0] rd;
    logic        rx_ok;

    initial begin
        rst        = 1'b0;
        cs         = 1'b0;
        we         = 1'b0;
        local_addr = 13'd0;
        wdata      = 32'd0;

        ps2_clk_tb  = 1'b1;
        ps2_data_tb = 1'b1;

        repeat (5) @(posedge clk);
        rst = 1'b1;
        repeat (5) @(posedge clk);

        // =====================================================
        // T1: valores despues de reset
        // =====================================================
        bus_read(13'h000, rd);
        check1 ("T1 rx_ready=0",    rd[0],    1'b0);
        check1 ("T1 tx_ready=1",    rd[1],    1'b1);
        check1 ("T1 rx_error=0",    rd[2],    1'b0);
        check1 ("T1 tx_error=0",    rd[3],    1'b0);
        check1 ("T1 kbd_enable=0",  rd[4],    1'b0);
        check32("T1 res[31:5]=0",   {5'd0, rd[31:5]}, 32'd0);

        // Salidas open-drain en reposo: deben estar liberadas.
        check1("T1 ps2_clk_o=Z en reposo",  ps2_clk_o,  1'bz);
        check1("T1 ps2_data_o=Z en reposo", ps2_data_o, 1'bz);

        // =====================================================
        // T2: habilitar teclado con CTRL[4]
        // =====================================================
        bus_write(13'h000, 32'h00000010);
        bus_read(13'h000, rd);
        check1("T2 kbd_enable=1", rd[4], 1'b1);

        // =====================================================
        // T3: recepcion normal de scancode 0x1C
        // =====================================================
        fork
            ps2_send_frame(8'h1C);
        join_none

        wait_rx_ready(rx_ok);

        if (!rx_ok) begin
            $display("FAIL  T3 timeout rx_ready");
            fail_count++;
        end else begin
            bus_read(13'h000, rd);
            check1("T3 rx_ready=1", rd[0], 1'b1);

            bus_read(13'h004, rd);
            check32("T3 RXDATA=0x1C", {24'd0, rd[7:0]}, 32'h0000001C);
        end

        // =====================================================
        // T4: leer RXDATA limpia rx_ready
        // =====================================================
        bus_read(13'h000, rd);
        check1("T4 rx_ready=0 post read", rd[0], 1'b0);

        // =====================================================
        // T5: prefijo break 0xF0 se expone al firmware
        // =====================================================
        fork
            ps2_send_frame(8'hF0);
        join_none

        wait_rx_ready(rx_ok);

        if (!rx_ok) begin
            $display("FAIL  T5 timeout 0xF0");
            fail_count++;
        end else begin
            bus_read(13'h004, rd);
            check32("T5 0xF0 expuesto al firmware", {24'd0, rd[7:0]}, 32'h000000F0);
        end

        // =====================================================
        // T6: prefijo extendido 0xE0 se expone al firmware
        // =====================================================
        fork
            ps2_send_frame(8'hE0);
        join_none

        wait_rx_ready(rx_ok);

        if (!rx_ok) begin
            $display("FAIL  T6 timeout 0xE0");
            fail_count++;
        end else begin
            bus_read(13'h004, rd);
            check32("T6 0xE0 expuesto al firmware", {24'd0, rd[7:0]}, 32'h000000E0);
        end

// =====================================================
// T7: escritura a TXDATA inicia transmision y libera lineas al terminar
// =====================================================
bus_write(13'h008, 32'h000000ED);

repeat (20) @(posedge clk);
bus_read(13'h000, rd);
check1("T7 tx_ready=0 durante TX", rd[1], 1'b0);

// No se fuerza ACK en esta prueba. El transmisor vuelve a IDLE por timeout.
// En el RTL actual tx_error no queda latcheado; se limpia al volver a IDLE.
#(5_000_000);

bus_read(13'h000, rd);
check1("T7 tx_ready=1 post timeout TX", rd[1], 1'b1);
check1("T7 tx_error=0 post timeout TX", rd[3], 1'b0);
check1("T7 ps2_clk_o=Z post TX",  ps2_clk_o,  1'bz);
check1("T7 ps2_data_o=Z post TX", ps2_data_o, 1'bz);

        // =====================================================
        // T8: trama con paridad incorrecta
        // =====================================================
        fork
            ps2_send_bad_frame(8'h45);
        join_none

        #(PS2_HALF * 40);
        repeat (10) @(posedge clk);

        bus_read(13'h000, rd);
        check1("T8 rx_error=1 trama erronea", rd[2], 1'b1);
        check1("T8 rx_ready=0 con error",     rd[0], 1'b0);

        // =====================================================
        // T9: bits reservados deben leer cero
        // =====================================================
        check32("T9 bits[31:5]=0", {5'd0, rd[31:5]}, 32'd0);

        // =====================================================
        // T10: cs=0 no debe escribir CTRL
        // =====================================================
        cs         = 1'b0;
        we         = 1'b1;
        local_addr = 13'h000;
        wdata      = 32'hFFFFFFFF;

        @(posedge clk);
        @(posedge clk);

        we         = 1'b0;
        local_addr = 13'd0;
        wdata      = 32'd0;

        bus_read(13'h000, rd);
        check1("T10 cs=0 no borra kbd_enable", rd[4], 1'b1);

        // =====================================================
        // Resumen
        // =====================================================
        #1000;

        if (fail_count == 0) begin
            $display("\n==== RESULT: ALL TESTS PASSED ====");
        end else begin
            $display("\n==== RESULT: %0d FAILED ====", fail_count);
        end

        $finish;
    end

    initial begin
        #120_000_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
