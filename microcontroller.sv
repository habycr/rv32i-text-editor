// =============================================================================
// microcontroller.sv
// -----------------------------------------------------------------------------
// Top-level del sistema completo en la DE1-SoC.
//
// Este archivo no implementa la CPU ni los periféricos por dentro; su trabajo es
// unirlos en un solo diseño: conecta reloj/reset, ROM, RAM, bus de datos,
// Address Translator, UART, PS/2, Timer y VGA.
//
// La CPU ve dos caminos principales:
//   - Camino de instrucciones: prog_addr -> ROM -> prog_in.
//   - Camino de datos: data_addr/data_out/we -> Address Translator -> RAM o
//     periféricos -> data_in.
//
// Para esta versión, todo el sistema digital principal trabaja a 25 MHz usando
// el clock generado por el PLL. Eso ayuda a cerrar timing y mantiene el VGA en
// su frecuencia de píxel esperada para 640x480@60Hz.
// =============================================================================

module microcontroller #(
    // Archivo .hex (formato $readmemh) con el programa del editor de texto.
    // Default "rom.hex" para que la SINTESIS (este modulo es el top) embeba el
    // firmware en la ROM M10K. Si queda "", la ROM se sintetiza llena de NOPs y
    // la CPU no escribe nada -> pantalla VGA negra en placa (aunque simule bien
    // porque el testbench pasa el .hex explicitamente). Un testbench puede
    // sobreescribir este parametro si necesita otra imagen o ROM vacia.
    parameter ROM_INIT_FILE = "rom.hex"
)(
    // Reloj y reset
    input  logic        CLOCK_50,      // Reloj de entrada de la FPGA: 50 MHz
    input  logic        rst_n,         // Reset general activo en bajo

    // Teclado PS/2 bidireccional
    inout  wire         PS2_CLK,      // Línea de clock PS/2; es inout porque teclado y FPGA pueden manejarla
    inout  wire         PS2_DAT,      // Línea de datos PS/2; también es bidireccional por el protocolo

    // UART
    input  logic        UART_RXD,     // Entrada serial desde la PC hacia la FPGA
    output logic        UART_TXD,     // Salida serial desde la FPGA hacia la PC

    // VGA ADV7123 DAC, 640x480@60Hz
    output logic        VGA_HS,       // Pulso de sincronía horizontal
    output logic        VGA_VS,       // Pulso de sincronía vertical
    output logic [7:0]  VGA_R,        // Canal rojo hacia el DAC VGA
    output logic [7:0]  VGA_G,        // Canal verde hacia el DAC VGA
    output logic [7:0]  VGA_B,        // Canal azul hacia el DAC VGA
    output logic        VGA_CLK,      // Clock de píxel entregado al DAC
    output logic        VGA_BLANK_N,  // Blank activo en bajo; se deja en 1 para habilitar video
    output logic        VGA_SYNC_N    // Sync compuesto no usado; en la DE1-SoC se deja fijo en 0
);

    // =====================================================================
    // Relojes
    // =====================================================================
    //
    // CLOCK_50 entra desde la placa.
    // El PLL genera clk_25.
    //
    // Decisión de timing:
    //   - VGA usa clk_25 como reloj de píxel.
    //   - CPU, ROM, RAM, bus y periféricos también usan clk_25 como clk_sys.
    //
    // Esto elimina la ruta crítica de medio ciclo que existía cuando la ROM
    // leía en negedge y el register_file escribía en posedge a 50 MHz.
    // Con 25 MHz, medio ciclo pasa de 10 ns a 20 ns.
    // =====================================================================

    logic clk_50;      // Alias interno del CLOCK_50 de la placa
    logic clk_25;      // Clock generado por el PLL; se usa como pixel clock y system clock
    logic clk_sys;     // Clock común para CPU, memorias y periféricos
    logic pll_locked;  // Indica que el PLL ya estabilizó su salida
    logic sys_rst_n;   // Reset final del sistema, ya condicionado por rst_n y pll_locked

    // Se usan aliases para que el resto del top sea más legible.
    assign clk_50  = CLOCK_50;
    assign clk_sys = clk_25;

    // PLL del proyecto. En simulación normalmente se usa un bypass dentro del wrapper.
    timer_pll_wrapper u_vga_pll (
        .refclk_i    (clk_50),
        .rst_i       (rst_n),
        .timer_clk_o (clk_25),
        .locked_o    (pll_locked)
    );

    // Todo el sistema sale de reset solo cuando el reset externo está liberado
    // y el PLL ya bloqueó. Esto evita que CPU/periféricos arranquen con clk_sys
    // inestable.
    assign sys_rst_n = rst_n & pll_locked;

    // =====================================================================
    // Buses internos de la CPU
    // =====================================================================

    logic [31:0] prog_addr;  // Dirección de instrucción generada por el PC de la CPU
    logic [31:0] prog_in;    // Instrucción leída desde la ROM

    logic [31:0] data_addr;  // Dirección usada por lw/sw en el bus de datos
    logic [31:0] data_out;   // Dato que la CPU escribe hacia RAM o periféricos
    logic [31:0] data_in;    // Dato que regresa hacia la CPU en una lectura
    logic        data_we;    // Write enable original que sale de la CPU

    // =====================================================================
    // CPU
    // =====================================================================

    // Núcleo RV32I monociclo. Solo recibe una instrucción y expone un bus de datos simple.
    riscv_cpu u_cpu (
        .clk_i       (clk_sys),
        .rst_i       (sys_rst_n),
        .prog_addr_o (prog_addr),
        .prog_in_i   (prog_in),
        .data_addr_o (data_addr),
        .data_out_o  (data_out),
        .data_in_i   (data_in),
        .we_o        (data_we)
    );

    // =====================================================================
    // ROM de programa
    // 8 KB, lectura en flanco negativo, ahora dentro del dominio clk_sys=25MHz.
    // =====================================================================

    rom #(
        .INIT_FILE (ROM_INIT_FILE)
    ) u_rom (
        .clk           (clk_sys),
        .ProgAddress_o (prog_addr),
        .ProgIn_i      (prog_in)
    );

    // =====================================================================
    // Address Translator
    // =====================================================================

    logic [12:0] local_addr;   // Dirección reducida para indexar RAM/periféricos internamente
    logic        bus_we;       // Write enable ya validado por el Address Translator

    logic        cs_ram;        // Selección de RAM de datos
    logic        cs_uart;       // Selección del periférico UART
    logic        cs_ps2;        // Selección del periférico PS/2
    logic        cs_timer;      // Selección del Timer
    logic        cs_vga_ctrl;   // Selección del registro de control VGA
    logic        cs_vga_buffer; // Selección del buffer de texto VGA

    // Traduce direcciones absolutas del firmware a chip-selects y direcciones locales.
    address_translator u_atrans (
        .addr_i          (data_addr),
        .we_i            (data_we),
        .local_addr_o    (local_addr),
        .we_o            (bus_we),
        .cs_ram_o        (cs_ram),
        .cs_uart_o       (cs_uart),
        .cs_ps2_o        (cs_ps2),
        .cs_timer_o      (cs_timer),
        .cs_vga_ctrl_o   (cs_vga_ctrl),
        .cs_vga_buffer_o (cs_vga_buffer)
    );

    logic cs_vga;

    // El controlador VGA recibe una sola señal de chip-select.
    // Internamente distingue entre control y buffer usando la dirección.
    assign cs_vga = cs_vga_ctrl | cs_vga_buffer;

    // =====================================================================
    // RAM de datos
    // 4 KB, lectura síncrona posedge, con stall de lw en CPU.
    // =====================================================================

    logic [31:0] ram_rdata; // Dato leído desde la RAM hacia el mux final

    // RAM de trabajo usada por el firmware para pila y datos temporales.
    ram u_ram (
        .clk          (clk_sys),
        .local_addr_o (local_addr),
        .we_o         (bus_we),
        .cs_ram_o     (cs_ram),
        .DataOut_o    (data_out),
        .ram_data_o   (ram_rdata)
    );

    // =====================================================================
    // UART
    // Ahora corre con clk_sys=25MHz.
    // baud_gen.sv debe usar DIVISOR=217 para mantener 115200 baud.
    // =====================================================================

    logic [31:0] uart_rdata; // Lectura de registros UART: status, RXDATA, etc.

    // UART mapeado a memoria. Lo usa el comando :w/:r del editor para guardar/cargar texto.
    uart_peripheral u_uart (
        .clk_i        (clk_sys),
        .rst_i        (sys_rst_n),
        .cs_i         (cs_uart),
        .we_i         (bus_we),
        .local_addr_i (local_addr),
        .wdata_i      (data_out),
        .rdata_o      (uart_rdata),
        .uart_rx_i    (UART_RXD),
        .uart_tx_o    (UART_TXD)
    );

    // =====================================================================
    // PS/2
    // Ahora corre con clk_sys=25MHz.
    // ps2_tx.sv debe usar constantes temporales recalculadas para 25MHz.
    // =====================================================================

    logic [31:0] ps2_rdata;   // Lectura de registros PS/2: estado y dato recibido
    logic        ps2_clk_drv;  // Valor que el periférico intenta manejar sobre PS2_CLK
    logic        ps2_data_drv; // Valor que el periférico intenta manejar sobre PS2_DAT

    // PS/2 mapeado a memoria. Entrega scancodes del teclado al firmware.
    ps2_peripheral u_ps2 (
        .clk_i        (clk_sys),
        .rst_i        (sys_rst_n),
        .cs_i         (cs_ps2),
        .we_i         (bus_we),
        .local_addr_i (local_addr),
        .wdata_i      (data_out),
        .rdata_o      (ps2_rdata),
        .ps2_clk_i    (PS2_CLK),
        .ps2_data_i   (PS2_DAT),
        .ps2_clk_o    (ps2_clk_drv),
        .ps2_data_o   (ps2_data_drv)
    );

    // El periférico PS/2 se encarga de liberar o manejar las líneas según el protocolo.
    // La lógica concreta de alta impedancia/open-collector está encapsulada en ese bloque.
    assign PS2_CLK = ps2_clk_drv;
    assign PS2_DAT = ps2_data_drv;

    // =====================================================================
    // Timer
    // Ahora corre con clk_sys=25MHz, por eso CLK_FREQ_HZ cambia a 25_000_000.
    // =====================================================================

    logic [31:0] timer_rdata; // Dato de lectura del Timer hacia la CPU

    // Timer mapeado a memoria. Deja una base de tiempo de 1 kHz para el sistema.
    timer_peripheral #(
        .CLK_FREQ_HZ (25_000_000),
        .TICK_HZ     (1000)
    ) u_timer (
        .clk_i        (clk_sys),
        .rst_i        (sys_rst_n),
        .cs_i         (cs_timer),
        .we_i         (bus_we),
        .local_addr_i (local_addr),
        .wdata_i      (data_out),
        .rdata_o      (timer_rdata)
    );

    // =====================================================================
    // VGA
    // CPU-side del VGA usa clk_sys.
    // Pixel-side usa clk_25.
    // En este ajuste ambos relojes son el mismo clk_25, pero se conservan
    // los dos puertos del controlador para no cambiar su interfaz.
    // =====================================================================

    logic [31:0] vga_rdata; // Dato leído del controlador VGA
    logic [3:0]  vga_r4;    // Color rojo interno de 4 bits
    logic [3:0]  vga_g4;    // Color verde interno de 4 bits
    logic [3:0]  vga_b4;    // Color azul interno de 4 bits

    // Controlador de texto VGA. Recibe escrituras de la CPU y genera la señal de video.
    vga_controller u_vga (
        .clk_50_i (clk_sys),
        .clk_25_i (clk_25),
        .rst_i    (sys_rst_n),
        .addr_i   (data_addr),
        .wdata_i  (data_out),
        .we_i     (bus_we),
        .cs_vga_i (cs_vga),
        .rdata_o  (vga_rdata),
        .hsync_o  (VGA_HS),
        .vsync_o  (VGA_VS),
        .r_o      (vga_r4),
        .g_o      (vga_g4),
        .b_o      (vga_b4)
    );

    // El controlador trabaja con colores de 4 bits por canal.
    // Para alimentar el DAC de 8 bits, se duplica el nibble: 0xA -> 0xAA.
    assign VGA_R = {vga_r4, vga_r4};
    assign VGA_G = {vga_g4, vga_g4};
    assign VGA_B = {vga_b4, vga_b4};

    // Señales fijas requeridas por la interfaz VGA de la placa.
    // El clock de salida es el mismo pixel clock de 25 MHz.
    assign VGA_CLK     = clk_25;
    assign VGA_BLANK_N = 1'b1;
    assign VGA_SYNC_N  = 1'b0;

    // =====================================================================
    // Mux de lectura hacia CPU
    // =====================================================================

    // Mux final de lectura hacia la CPU.
    // Si se selecciona RAM, se devuelve ram_rdata.
    // Si se selecciona un periférico, se combinan sus salidas por OR porque solo
    // uno debería estar activo para una dirección válida del mapa de memoria.
    assign data_in = cs_ram ? ram_rdata
                            : (uart_rdata | ps2_rdata | timer_rdata | vga_rdata);

endmodule