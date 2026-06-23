// Decodifica cuál periférico debe responder dentro del espacio 0x0001_xxxx.
// Este módulo recibe el offset de periféricos y activa solo el chip-select
// que corresponde a ese rango de direcciones.

// También calcula una dirección local de 13 bits.
// Esa dirección local empieza en cero desde la base del periférico seleccionado.

module peripheral_decoder (
// Indica que la dirección ya fue reconocida como parte del espacio general
// de periféricos. Si esta señal está en cero, ningún periférico debe activarse.
input logic cs_periph_space_i,

// Offset dentro de la región 0x0001_xxxx.
// Con este valor se decide si el acceso va para UART, PS/2, timer o VGA.
input  logic [15:0] periph_offset_i,

// Chip-select del UART.
output logic        cs_uart_o,

// Chip-select del periférico PS/2.
output logic        cs_ps2_o,

// Chip-select del timer.
output logic        cs_timer_o,

// Chip-select de los registros de control del VGA.
output logic        cs_vga_ctrl_o,

// Chip-select del buffer de texto del VGA.
output logic        cs_vga_buffer_o,

// Offset local que verá el periférico seleccionado.
// Por ejemplo, si se accede a la base del UART, este valor queda en cero.
output logic [12:0] periph_local_addr_o

);

// Rango de direcciones reservado para el UART.
localparam logic [15:0] UART_BASE       = 16'h0040;
localparam logic [15:0] UART_END        = 16'h0048;

// Rango de direcciones reservado para el periférico PS/2.
localparam logic [15:0] PS2_BASE        = 16'h0050;
localparam logic [15:0] PS2_END         = 16'h0058;

// Rango de direcciones reservado para el timer.
localparam logic [15:0] TIMER_BASE      = 16'h0060;
localparam logic [15:0] TIMER_END       = 16'h0064;

// Dirección de los registros de control del VGA.
// En este caso solo hay una palabra de control en 0x0120.
localparam logic [15:0] VGA_CTRL_BASE   = 16'h0120;
localparam logic [15:0] VGA_CTRL_END    = 16'h0120;

// Rango usado por el buffer de texto del VGA.
// Aquí caen las posiciones de caracteres que se muestran en pantalla.
localparam logic [15:0] VGA_BUFFER_BASE = 16'h1000;
localparam logic [15:0] VGA_BUFFER_END  = 16'h2DFF;

// Calcula el offset local restando la base del periférico.
// Se dejan solo 13 bits porque ese es el ancho usado por el bus local.
function logic [12:0] offset13;
    input logic [15:0] addr;
    input logic [15:0] base;

    logic [15:0] diff;

    begin
        diff     = addr - base;
        offset13 = diff[12:0];
    end
endfunction

always_comb begin
    // Por defecto no se selecciona ningún periférico.
    // Esto evita que quede activo un chip-select de una evaluación anterior.
    cs_uart_o        = 1'b0;
    cs_ps2_o         = 1'b0;
    cs_timer_o       = 1'b0;
    cs_vga_ctrl_o    = 1'b0;
    cs_vga_buffer_o  = 1'b0;

    // Si la dirección no coincide con ningún rango válido,
    // la dirección local se mantiene en cero.
    periph_local_addr_o = 13'b0;

    // Solo se intenta decodificar si antes se confirmó que la dirección
    // pertenece al espacio general de periféricos.
    if (cs_periph_space_i) begin

        // Acceso al UART.
        if ((periph_offset_i >= UART_BASE) &&
            (periph_offset_i <= UART_END)) begin

            cs_uart_o = 1'b1;
            periph_local_addr_o = offset13(periph_offset_i, UART_BASE);
        end

        // Acceso al periférico PS/2.
        else if ((periph_offset_i >= PS2_BASE) &&
                 (periph_offset_i <= PS2_END)) begin

            cs_ps2_o = 1'b1;
            periph_local_addr_o = offset13(periph_offset_i, PS2_BASE);
        end

        // Acceso al timer.
        else if ((periph_offset_i >= TIMER_BASE) &&
                 (periph_offset_i <= TIMER_END)) begin

            cs_timer_o = 1'b1;
            periph_local_addr_o = offset13(periph_offset_i, TIMER_BASE);
        end

        // Acceso a los registros de control del VGA.
        else if ((periph_offset_i >= VGA_CTRL_BASE) &&
                 (periph_offset_i <= VGA_CTRL_END)) begin

            cs_vga_ctrl_o = 1'b1;
            periph_local_addr_o = offset13(periph_offset_i, VGA_CTRL_BASE);
        end

        // Acceso al buffer de texto del VGA.
        else if ((periph_offset_i >= VGA_BUFFER_BASE) &&
                 (periph_offset_i <= VGA_BUFFER_END)) begin

            cs_vga_buffer_o = 1'b1;
            periph_local_addr_o = offset13(periph_offset_i, VGA_BUFFER_BASE);
        end
    end
end

endmodule