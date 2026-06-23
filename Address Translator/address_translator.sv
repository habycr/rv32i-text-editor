
// Traductor principal de direcciones del bus de datos.
// Recibe la dirección que genera la CPU y decide qué bloque del sistema debe atenderla:
// RAM, UART, PS/2, timer, registros de control VGA o buffer de texto VGA.

// Además de activar el chip-select correspondiente, también genera una dirección local.
// Esa dirección local ya no representa una dirección completa del sistema,
// sino un offset interno para el bloque que fue seleccionado.

module address_translator (
    // Dirección de datos generada por la CPU.
    // Viene desde el datapath como DataAddress_o.
    input  logic [31:0] addr_i,

    // Señal de escritura generada por la CPU.
    // Aquí no se modifica, solo se propaga hacia el bus local.
    input  logic        we_i,

    // Dirección local que verá la RAM o el periférico seleccionado.
    // Su interpretación depende de cuál chip-select esté activo.
    output logic [12:0] local_addr_o,

    // Señal de escritura hacia el resto del sistema.
    // Se deja como salida separada para mantener clara la interfaz del traductor.
    output logic        we_o,

    // Se activa cuando la dirección pertenece al rango de RAM:
    // 0x0000_2000 - 0x0000_2FFF.
    output logic        cs_ram_o,

    // Se activa cuando la dirección corresponde al periférico UART.
    output logic        cs_uart_o,

    // Se activa cuando la dirección corresponde al periférico PS/2.
    output logic        cs_ps2_o,

    // Se activa cuando la dirección corresponde al timer.
    output logic        cs_timer_o,

    // Se activa cuando se accede a los registros de control del VGA.
    output logic        cs_vga_ctrl_o,

    // Se activa cuando se accede al buffer de texto del VGA.
    output logic        cs_vga_buffer_o
);

    // Parte alta de la dirección.
    // Sirve para reconocer regiones grandes del mapa, como el espacio de periféricos.
    logic [15:0] addr_region;

    // Parte baja de la dirección.
    // Dentro de 0x0001_xxxx funciona como offset para identificar el periférico.
    logic [15:0] periph_offset;

    // Bits bajos de la dirección original.
    // Se usan como base para formar direcciones locales dentro de RAM o periféricos.
    logic [12:0] raw_local_addr;

    // Indica que la dirección cae dentro del espacio general de periféricos.
    // En este punto todavía no se sabe cuál periférico específico fue seleccionado.
    logic        cs_periph_space;

    // Dirección local calculada para la RAM.
    logic [12:0] ram_local_addr;

    // Dirección local calculada para el periférico seleccionado.
    logic [12:0] periph_local_addr;

    // La señal de escritura pasa directo.
    // Cada bloque decide si la usa o no según su propio chip-select.
    assign we_o = we_i;

    // Parte la dirección global en campos más simples.
    // Así los demás decodificadores no tienen que estar repitiendo cortes de bits.
    address_splitter u_address_splitter (
        .addr_i           (addr_i),
        .addr_region_o    (addr_region),
        .periph_offset_o  (periph_offset),
        .raw_local_addr_o (raw_local_addr)
    );

    // Revisa si la dirección pertenece al rango reservado para RAM.
    // Si coincide, activa cs_ram_o y genera el offset interno de RAM.
    ram_decoder u_ram_decoder (
        .addr_i           (addr_i),
        .raw_local_addr_i (raw_local_addr),
        .cs_ram_o         (cs_ram_o),
        .ram_local_addr_o (ram_local_addr)
    );

    // Revisa si la dirección está dentro de la página general de periféricos.
    // Esto solo valida la región 0x0001_xxxx; todavía no selecciona UART, PS/2,
    // timer ni VGA.
    peripheral_predecoder u_peripheral_predecoder (
        .addr_region_i     (addr_region),
        .cs_periph_space_o (cs_periph_space)
    );

    // Decodifica el periférico específico usando el offset dentro de 0x0001_xxxx.
    // Solo uno de los chip-select debería activarse para una dirección válida.
    // También calcula el offset local que usará ese periférico.
    peripheral_decoder u_peripheral_decoder (
        .cs_periph_space_i   (cs_periph_space),
        .periph_offset_i     (periph_offset),

        .cs_uart_o           (cs_uart_o),
        .cs_ps2_o            (cs_ps2_o),
        .cs_timer_o          (cs_timer_o),
        .cs_vga_ctrl_o       (cs_vga_ctrl_o),
        .cs_vga_buffer_o     (cs_vga_buffer_o),

        .periph_local_addr_o (periph_local_addr)
    );

    // Escoge qué dirección local se entrega hacia el bus.
    // Si el acceso fue a RAM, usa el offset de RAM.
    // Si fue a un periférico, usa el offset calculado para ese periférico.
    local_address_mux u_local_address_mux (
        .cs_ram_i            (cs_ram_o),
        .cs_uart_i           (cs_uart_o),
        .cs_ps2_i            (cs_ps2_o),
        .cs_timer_i          (cs_timer_o),
        .cs_vga_ctrl_i       (cs_vga_ctrl_o),
        .cs_vga_buffer_i     (cs_vga_buffer_o),

        .ram_local_addr_i    (ram_local_addr),
        .periph_local_addr_i (periph_local_addr),

        .local_addr_o        (local_addr_o)
    );

endmodule
