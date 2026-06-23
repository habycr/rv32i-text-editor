// ============================================================================
// QUÉ HACE ESTE ARCHIVO (en palabras simples):
//   Hasta este punto del sistema, ya sabemos: (a) qué carácter va en la
//   casilla actual y de qué colores (gracias a text_buffer), y (b) si el
//   píxel que se está dibujando ahora mismo es parte del "trazo" de la
//   letra o es del fondo de su casilla (gracias a font_rom). Lo único que
//   falta es decidir: ¿con qué color exacto pinto este píxel?
//
//   Este módulo es el "mezclador de pintura final": toma esas decisiones y
//   las convierte en valores concretos de Rojo, Verde y Azul (RGB) que se
//   envían al monitor. Usa una paleta de 16 colores clásica conocida como
//   "paleta CGA" (la de las primeras tarjetas gráficas de PC).
//
//   Además resuelve dos casos especiales:
//     - Si estamos fuera del área visible de la pantalla -> todo negro.
//     - Si en esa casilla debe dibujarse el cursor parpadeante -> se
//       "invierten" los colores de letra y fondo, dando el efecto visual
//       de un bloque resaltado (como el cursor de una terminal).
// ============================================================================

module cga_palette (
    input  logic [3:0] fg_color_i,   // Color de la letra de la casilla actual (0-15)
    input  logic [3:0] bg_color_i,   // Color de fondo de la casilla actual (0-15)
    input  logic       pixel_bit_i,  // 1 = este píxel es parte del trazo de la letra
    input  logic       video_on_i,   // 1 = estamos dentro del área visible de la pantalla
    input  logic       cursor_on_i,  // 1 = aquí debe dibujarse el cursor (parpadeo)
    output logic [3:0] r_o,          // Componente Roja de salida hacia el monitor (4 bits)
    output logic [3:0] g_o,          // Componente Verde de salida hacia el monitor (4 bits)
    output logic [3:0] b_o           // Componente Azul de salida hacia el monitor (4 bits)
);
    // Comentario de cabecera original: explica el origen de la tabla de colores
    // Tabla CGA: {R,G,B} 4 bits cada uno
    // Índice: 0=negro, 1=azul, 2=verde, 3=cian, 4=rojo,
    //         5=magenta, 6=marrón, 7=gris claro,
    //         8=gris oscuro, 9=azul brillante, 10=verde brillante,
    //         11=cian brillante, 12=rojo brillante,
    //         13=magenta brillante, 14=amarillo, 15=blanco

    // ------------------------------------------------------------------
    // "function automatic" define una pequeña función reutilizable dentro
    // del módulo: recibe un número de 4 bits (índice de color, 0 a 15) y
    // devuelve los 12 bits correspondientes (4 de rojo + 4 de verde + 4 de
    // azul) según la tabla de colores CGA de toda la vida. Es como una
    // "tabla de búsqueda" escrita en forma de switch/case.
    // ------------------------------------------------------------------
    function automatic [11:0] cga_rgb(input [3:0] idx);
        case (idx)
            // El formato 12'hRGB agrupa los 12 bits en tres grupos
            // hexadecimales: el primero es Rojo, el segundo Verde y el
            // tercero Azul. Por ejemplo 12'hF00 = rojo al máximo, sin
            // verde ni azul = "rojo brillante".
            4'd0:  cga_rgb = 12'h000; // negro
            4'd1:  cga_rgb = 12'h00A; // azul
            4'd2:  cga_rgb = 12'h0A0; // verde
            4'd3:  cga_rgb = 12'h0AA; // cian
            4'd4:  cga_rgb = 12'hA00; // rojo
            4'd5:  cga_rgb = 12'hA0A; // magenta
            4'd6:  cga_rgb = 12'hA60; // marrón
            4'd7:  cga_rgb = 12'hAAA; // gris claro
            4'd8:  cga_rgb = 12'h555; // gris oscuro
            4'd9:  cga_rgb = 12'h55F; // azul brillante
            4'd10: cga_rgb = 12'h5F5; // verde brillante
            4'd11: cga_rgb = 12'h5FF; // cian brillante
            4'd12: cga_rgb = 12'hF55; // rojo brillante
            4'd13: cga_rgb = 12'hF5F; // magenta brillante
            4'd14: cga_rgb = 12'hFF5; // amarillo
            4'd15: cga_rgb = 12'hFFF; // blanco
            // "default" cubre cualquier otro caso (que en teoría no debería
            // ocurrir, ya que solo hay 16 valores posibles con 4 bits) y
            // devuelve negro por seguridad.
            default: cga_rgb = 12'h000;
        endcase
    endfunction

    // Señales internas auxiliares que usaremos para ir armando la decisión
    // final de color paso a paso.
    logic       sel_fg;     // 1 = en este píxel se debe usar el color de letra
    logic [3:0] color_idx;  // índice (0-15) del color finalmente elegido
    logic [11:0] rgb;       // los 12 bits RGB resultantes de consultar la tabla

    // ------------------------------------------------------------------
    // Paso 1: decidir si este píxel debe pintarse con el color de "letra"
    // (fg = foreground) o de "fondo" (bg = background).
    //
    // En el caso normal: si pixel_bit_i=1 (el píxel pertenece al trazo de
    // la letra) usamos el color de letra; si es 0, el de fondo.
    //
    // PERO si cursor_on_i=1 (debemos dibujar el cursor parpadeante en esta
    // casilla), invertimos esa decisión con el operador "~" (negación):
    // donde antes iba el color de letra, ahora va el de fondo, y viceversa.
    // Esto produce visualmente un "bloque invertido", el efecto típico de
    // un cursor de texto resaltado.
    //
    // El operador "?:" es un "si-entonces-si-no" compacto:
    //   condición ? valor_si_verdadero : valor_si_falso
    // ------------------------------------------------------------------
    assign sel_fg     = cursor_on_i ? ~pixel_bit_i : pixel_bit_i;

    // Paso 2: según lo decidido, escogemos el ÍNDICE de color (0-15) que
    // corresponde: el de la letra (fg_color_i) o el del fondo (bg_color_i).
    assign color_idx  = sel_fg ? fg_color_i : bg_color_i;

    // Paso 3: convertimos ese índice en sus valores reales de Rojo, Verde
    // y Azul consultando la función/tabla de colores definida arriba.
    assign rgb        = cga_rgb(color_idx);

    // ------------------------------------------------------------------
    // Paso final: producir la salida real hacia el monitor.
    //
    // "always_comb" describe lógica puramente combinacional: el resultado
    // se recalcula al instante cada vez que cambia cualquiera de las
    // señales que usa adentro (no depende de un reloj).
    //
    // Si video_on_i=0 (estamos fuera del área visible: en los "colchones"
    // o pulsos de sincronismo), forzamos todo a negro (0,0,0); es la forma
    // correcta de "apagar el haz" durante esos intervalos según el
    // estándar VGA.
    //
    // Si video_on_i=1, repartimos los 12 bits calculados (rgb) en sus tres
    // componentes de 4 bits cada uno: los 4 bits más significativos [11:8]
    // son el rojo, los 4 de en medio [7:4] son el verde, y los 4 menos
    // significativos [3:0] son el azul.
    // ------------------------------------------------------------------
    always_comb begin
        if (!video_on_i) begin
            r_o = 4'h0;
            g_o = 4'h0;
            b_o = 4'h0;
        end else begin
            r_o = rgb[11:8];
            g_o = rgb[7:4];
            b_o = rgb[3:0];
        end
    end
endmodule
