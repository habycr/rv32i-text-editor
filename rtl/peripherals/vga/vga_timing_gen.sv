// ============================================================================
// QUÉ HACE ESTE ARCHIVO (en palabras simples):
//   Una pantalla VGA no recibe "una imagen" de una sola vez. En realidad el
//   monitor dibuja la pantalla punto por punto (píxel por píxel), de
//   izquierda a derecha y de arriba hacia abajo, una y otra vez, 60 veces
//   por segundo. Para que el monitor sepa CUÁNDO debe empezar una nueva
//   línea y CUÁNDO debe empezar una pantalla nueva, hay que enviarle dos
//   señales especiales llamadas "sincronismo horizontal" (hsync) y
//   "sincronismo vertical" (vsync), además de "apagar" el haz durante los
//   tiempos muertos entre líneas/pantallas.
//
//   Este módulo es el "director de orquesta" del VGA: lleva la cuenta de en
//   qué columna (x) y fila (y) de la pantalla estamos en cada instante, y a
//   partir de esa cuenta genera hsync, vsync y una señal "video_on" que
//   indica si en este instante se está dibujando dentro del área visible
//   (640x480) o en una de las zonas muertas alrededor.
//
//   Funciona al ritmo del reloj de píxel de 25 MHz (generado por
//   vga_clk_gen), que es la velocidad estándar para resolución 640x480 a
//   60 Hz de actualización.
// ============================================================================

// Definición del módulo y su lista de conectores (puertos) hacia el exterior
module vga_timing_gen (
    input  logic        clk_25_i,    // Reloj de píxel: "late" 25 millones de veces por segundo
    input  logic        rst_i,       // Reset activo en bajo (0 = reiniciar)
    output logic        hsync_o,     // Pulso de sincronismo horizontal hacia el monitor
    output logic        vsync_o,     // Pulso de sincronismo vertical hacia el monitor
    output logic [9:0]  hcount_o,    // Columna (posición horizontal) del píxel actual: 0 a 799
    output logic [9:0]  vcount_o,    // Fila (posición vertical) del píxel actual: 0 a 524
    output logic        video_on_o   // 1 = estamos dibujando dentro del área visible 640x480
);
    // ------------------------------------------------------------------
    // "localparam" define una constante con nombre, para no escribir
    // números "mágicos" sueltos por el código y que sea más fácil de leer
    // y modificar. Aquí se describen las medidas (en píxeles) de cada
    // franja de la imagen VGA, según el estándar de video 640x480 @ 60 Hz.
    //
    // Una línea horizontal de la pantalla NO mide solo 640 píxeles: el
    // monitor necesita "tiempo extra" antes y después para reubicar el haz.
    // Esas franjas de tiempo extra se llaman "front porch", "sync" (pulso
    // de sincronismo) y "back porch". Lo mismo ocurre verticalmente con
    // las líneas (filas) de la imagen completa.
    // ------------------------------------------------------------------

    // ----- Medidas horizontales (en cantidad de píxeles por línea) -----
    localparam H_ACTIVE     = 640;  // Píxeles realmente visibles en una línea
    localparam H_FRONT      = 16;   // "Colchón" de píxeles después del área visible
    localparam H_SYNC       = 96;   // Duración del pulso de sincronismo horizontal
    localparam H_BACK       = 48;   // "Colchón" de píxeles antes de volver al área visible
    localparam H_TOTAL      = 800;  // Total de píxeles por línea = 640+16+96+48

    // ----- Medidas verticales (en cantidad de líneas por pantalla) -----
    localparam V_ACTIVE     = 480;  // Líneas realmente visibles en la pantalla
    localparam V_FRONT      = 10;   // "Colchón" de líneas después del área visible
    localparam V_SYNC       = 2;    // Duración del pulso de sincronismo vertical
    localparam V_BACK       = 33;   // "Colchón" de líneas antes de volver al área visible
    localparam V_TOTAL      = 525;  // Total de líneas por pantalla = 480+10+2+33

    // Posiciones (dentro del conteo total) en las que debe iniciar y
    // terminar cada pulso de sincronismo. Se calculan sumando las franjas
    // anteriores para ubicar exactamente "dónde cae" el pulso.
    localparam H_SYNC_START = H_ACTIVE + H_FRONT;          // = 656
    localparam H_SYNC_END   = H_SYNC_START + H_SYNC;       // = 752
    localparam V_SYNC_START = V_ACTIVE + V_FRONT;          // = 490
    localparam V_SYNC_END   = V_SYNC_START + V_SYNC;       // = 492

    // ------------------------------------------------------------------
    // Registros internos (memorias de 1 bit x 10 = 10 bits cada una) que
    // guardan en qué columna y fila va el "barrido" de la pantalla en este
    // momento. [9:0] significa "un grupo de 10 bits", suficiente para
    // contar de 0 a 1023 (necesitamos llegar hasta 799 y 524).
    // ------------------------------------------------------------------
    logic [9:0] hcount, vcount;

    // --------------------------------------------------------------
    // Bloque secuencial: se actualiza en cada flanco de subida del
    // reloj de píxel (25 MHz), o inmediatamente si se activa el reset.
    // Aquí es donde "avanza" el barrido de la pantalla, píxel a píxel
    // y línea a línea, como una máquina de escribir que recorre el
    // papel de izquierda a derecha y salta de renglón al llegar al borde.
    // --------------------------------------------------------------
    always_ff @(posedge clk_25_i or negedge rst_i) begin
        if (!rst_i) begin
            // Al reiniciar, ambos contadores vuelven a cero ('0 = todo en 0)
            hcount <= '0;
            vcount <= '0;
        end else begin
            // ¿Llegamos al final de la línea actual (último píxel, 799)?
            if (hcount == H_TOTAL - 1) begin
                hcount <= '0;             // Volvemos al inicio de la línea (columna 0)

                // Si además esta era la última línea de la pantalla (524)...
                if (vcount == V_TOTAL - 1)
                    vcount <= '0;         // ...reiniciamos también la fila (volvemos arriba)
                else
                    vcount <= vcount + 1'b1; // ...si no, pasamos a la siguiente línea
            end else begin
                // Caso normal: seguimos avanzando una columna a la derecha
                hcount <= hcount + 1'b1;
            end
        end
    end

    // ------------------------------------------------------------------
    // Generación de las señales de salida a partir de los contadores.
    // Estas son asignaciones "combinacionales" (assign): su valor se
    // recalcula automáticamente cada vez que cambian hcount o vcount,
    // sin esperar a un flanco de reloj.
    // ------------------------------------------------------------------

    // hsync_o: el pulso de sincronismo horizontal del estándar VGA es
    // "activo en bajo" (0 = pulso activo). Por eso se compara si hcount
    // está DENTRO de la zona de sincronismo (entre H_SYNC_START y
    // H_SYNC_END, sin incluir este último) y luego se invierte el
    // resultado con "~" para que sea 0 justo en esa zona y 1 en el resto.
    assign hsync_o    = ~(hcount >= H_SYNC_START && hcount < H_SYNC_END);

    // vsync_o: exactamente la misma idea, pero para el sincronismo vertical
    assign vsync_o    = ~(vcount >= V_SYNC_START && vcount < V_SYNC_END);

    // video_on_o: vale 1 (verdadero) únicamente cuando el "haz" está
    // dibujando dentro del rectángulo visible de 640x480; es decir, cuando
    // la columna actual es menor que 640 Y la fila actual es menor que 480.
    // Fuera de ese rectángulo (en los "colchones" y pulsos de sync) vale 0,
    // y el resto del sistema sabe que ahí no debe pintar nada (pantalla
    // "apagada" / color negro).
    assign video_on_o = (hcount < H_ACTIVE) && (vcount < V_ACTIVE);

    // Se exponen los contadores hacia afuera para que otros módulos
    // (como text_buffer o font_rom) sepan exactamente qué píxel se está
    // dibujando en este instante y puedan calcular qué color le corresponde.
    assign hcount_o   = hcount;
    assign vcount_o   = vcount;

endmodule
