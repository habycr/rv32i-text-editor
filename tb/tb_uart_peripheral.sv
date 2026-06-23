// FILE: Branch_FSM_Control_UART_PS2/tb/tb_uart_peripheral.sv
`timescale 1ns/1ps

module tb_uart_peripheral;


localparam CLK_PERIOD = 20;                  // 50 MHz
localparam BIT_TIME   = 434 * CLK_PERIOD;    // 115200 baud aprox.

logic        clk;
logic        rst;

logic        cs;
logic        we;
logic [12:0] local_addr;
logic [31:0] wdata;
logic [31:0] rdata;

logic        uart_rx;
logic        uart_tx;

int fail_count = 0;

uart_peripheral dut (
    .clk_i        (clk),
    .rst_i        (rst),
    .cs_i         (cs),
    .we_i         (we),
    .local_addr_i (local_addr),
    .wdata_i      (wdata),
    .rdata_o      (rdata),
    .uart_rx_i    (uart_rx),
    .uart_tx_o    (uart_tx)
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

task automatic check(
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

task automatic inject_rx_byte(input logic [7:0] data);
    integer i;

    // linea en reposo
    uart_rx = 1'b1;
    #(BIT_TIME);

    // start bit
    uart_rx = 1'b0;
    #(BIT_TIME);

    // datos LSB-first
    for (i = 0; i < 8; i = i + 1) begin
        uart_rx = data[i];
        #(BIT_TIME);
    end

    // stop bit
    uart_rx = 1'b1;
    #(BIT_TIME);

    // margen de reposo
    #(BIT_TIME);
endtask

task automatic wait_rx_ready(output logic ok);
    integer i;
    logic [31:0] rd_local;

    ok = 1'b0;

    for (i = 0; i < 50000; i = i + 1) begin
        @(posedge clk);
        bus_read(13'h000, rd_local);

        if (rd_local[1]) begin
            ok = 1'b1;
            i  = 50000;
        end
    end
endtask

task automatic wait_tx_ready(output logic ok);
    integer i;
    logic [31:0] rd_local;

    ok = 1'b0;

    for (i = 0; i < 50000; i = i + 1) begin
        @(posedge clk);
        bus_read(13'h000, rd_local);

        if (rd_local[0]) begin
            ok = 1'b1;
            i  = 50000;
        end
    end
endtask

task automatic capture_uart_tx_frame(
    output logic [9:0] cap
);
    integer bi;

    // espera a que la linea este en reposo antes de buscar el start
    wait (uart_tx == 1'b1);

    // espera start bit real
    wait (uart_tx == 1'b0);

    // centro del start bit
    #(BIT_TIME / 2);
    cap[0] = uart_tx;

    // centro de los 8 bits de datos
    for (bi = 1; bi <= 8; bi = bi + 1) begin
        #(BIT_TIME);
        cap[bi] = uart_tx;
    end

    // centro del stop bit
    #(BIT_TIME);
    cap[9] = uart_tx;
endtask

logic [31:0] rd;
logic        rx_ok;
logic        tx_ok;

initial begin
    rst        = 1'b0;
    cs         = 1'b0;
    we         = 1'b0;
    local_addr = 13'd0;
    wdata      = 32'd0;
    uart_rx    = 1'b1;

    repeat (5) @(posedge clk);
    rst = 1'b1;
    repeat (5) @(posedge clk);

    // =====================================================
    // T1: valores despues de reset
    // =====================================================
    bus_read(13'h000, rd);
    check("T1 tx_ready=1 tras reset", rd[0],    1'b1);
    check("T1 rx_ready=0 tras reset", rd[1],    1'b0);
    check("T1 bits[31:2]=0",          rd[31:2], 30'd0);

    // =====================================================
    // T2: cs=0 debe ignorar escritura
    // =====================================================
    cs         = 1'b0;
    we         = 1'b1;
    local_addr = 13'h004;
    wdata      = 32'h000000FF;

    @(posedge clk);
    @(posedge clk);

    we         = 1'b0;
    local_addr = 13'd0;
    wdata      = 32'd0;

    bus_read(13'h000, rd);
    check("T2 cs=0 no arranca TX", rd[0], 1'b1);

    // =====================================================
    // T3: transmision de 0x55 por escritura a TXDATA
    // =====================================================
    fork
        begin : capture_frame_t3
            logic [9:0] cap;

            capture_uart_tx_frame(cap);

            check("T3 start=0",       cap[0], 1'b0);
            check("T3 bit0=1 (0x55)", cap[1], 1'b1);
            check("T3 bit1=0",        cap[2], 1'b0);
            check("T3 bit2=1",        cap[3], 1'b1);
            check("T3 bit3=0",        cap[4], 1'b0);
            check("T3 bit4=1",        cap[5], 1'b1);
            check("T3 bit5=0",        cap[6], 1'b0);
            check("T3 bit6=1",        cap[7], 1'b1);
            check("T3 bit7=0",        cap[8], 1'b0);
            check("T3 stop=1",        cap[9], 1'b1);
        end

        begin : write_and_status_t3
            bus_write(13'h004, 32'h00000055);

            #(BIT_TIME * 2);
            bus_read(13'h000, rd);
            check("T3 tx_ready=0 durante TX", rd[0], 1'b0);
        end
    join

    wait_tx_ready(tx_ok);

    if (!tx_ok) begin
        $display("FAIL  T3 timeout tx_ready post TX");
        fail_count++;
    end else begin
        bus_read(13'h000, rd);
        check("T3 tx_ready=1 post TX", rd[0], 1'b1);
    end

    // =====================================================
    // T4: transmision por CTRL/STATUS[2]
    // Usa el ultimo byte cargado en TXDATA: 0x55
    // =====================================================
    fork
        begin : capture_frame_t4
            logic [9:0] cap;

            capture_uart_tx_frame(cap);

            check("T4 start=0 CTRL tx_start", cap[0], 1'b0);
            check("T4 bit0=1 CTRL",           cap[1], 1'b1);
            check("T4 bit1=0 CTRL",           cap[2], 1'b0);
            check("T4 bit2=1 CTRL",           cap[3], 1'b1);
            check("T4 bit3=0 CTRL",           cap[4], 1'b0);
            check("T4 bit4=1 CTRL",           cap[5], 1'b1);
            check("T4 bit5=0 CTRL",           cap[6], 1'b0);
            check("T4 bit6=1 CTRL",           cap[7], 1'b1);
            check("T4 bit7=0 CTRL",           cap[8], 1'b0);
            check("T4 stop=1 CTRL",           cap[9], 1'b1);
        end

        begin : write_ctrl_t4
            bus_write(13'h000, 32'h00000004);

            #(BIT_TIME * 2);
            bus_read(13'h000, rd);
            check("T4 tx_ready=0 durante TX por CTRL", rd[0], 1'b0);
        end
    join

    wait_tx_ready(tx_ok);

    if (!tx_ok) begin
        $display("FAIL  T4 timeout tx_ready post CTRL TX");
        fail_count++;
    end else begin
        bus_read(13'h000, rd);
        check("T4 tx_ready=1 post CTRL TX", rd[0], 1'b1);
    end

    // =====================================================
    // T5: recepcion de 0xA5
    // =====================================================
    fork
        inject_rx_byte(8'hA5);
    join_none

    wait_rx_ready(rx_ok);

    if (!rx_ok) begin
        $display("FAIL  T5 timeout rx_ready");
        fail_count++;
    end else begin
        bus_read(13'h000, rd);
        check("T5 rx_ready=1", rd[1], 1'b1);

        bus_read(13'h008, rd);
        check("T5 RXDATA=0xA5", rd[7:0], 8'hA5);
    end

    // =====================================================
    // T6: leer RXDATA limpia rx_ready
    // =====================================================
    bus_read(13'h000, rd);
    check("T6 rx_ready=0 post read", rd[1], 1'b0);

    // =====================================================
    // T7: recepcion de otro byte para verificar resincronizacion RX
    // =====================================================
    fork
        inject_rx_byte(8'h3C);
    join_none

    wait_rx_ready(rx_ok);

    if (!rx_ok) begin
        $display("FAIL  T7 timeout rx_ready segundo byte");
        fail_count++;
    end else begin
        bus_read(13'h000, rd);
        check("T7 rx_ready=1 segundo byte", rd[1], 1'b1);

        bus_read(13'h008, rd);
        check("T7 RXDATA=0x3C", rd[7:0], 8'h3C);
    end

    bus_read(13'h000, rd);
    check("T7 rx_ready=0 post read segundo byte", rd[1], 1'b0);

    // =====================================================
    // T8: lectura con cs=0 devuelve cero
    // =====================================================
    @(posedge clk);
    cs         = 1'b0;
    we         = 1'b0;
    local_addr = 13'h000;
    wdata      = 32'd0;

    @(posedge clk);
    check("T8 cs=0 rdata=0", rdata, 32'd0);

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
    #80_000_000;
    $display("TIMEOUT");
    $finish;
end


endmodule
