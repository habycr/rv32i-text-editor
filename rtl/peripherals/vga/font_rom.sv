// ============================================================================
// QUÉ HACE ESTE ARCHIVO (en palabras simples):
//   La pantalla no "sabe" dibujar letras: solo sabe encender o apagar
//   píxeles individuales. Para mostrar, por ejemplo, la letra 'A', alguien
//   tiene que decirle exactamente qué píxeles encender y cuáles dejar
//   apagados dentro del recuadro donde va esa letra.
//
//   Este módulo es justamente ese "alguien": una memoria de solo lectura
//   (ROM = Read-Only Memory) que ya trae grabado, para cada uno de los 256
//   caracteres posibles (letras, números, símbolos, etc. del alfabeto
//   CP437/IBM PC), el dibujo exacto de su forma como una cuadrícula de
//   8 columnas por 16 filas de píxeles (8x16).
//
//   Funciona como una "consulta": le decimos QUÉ carácter queremos
//   (char_code_i) y QUÉ FILA de su dibujo necesitamos (row_i), y el módulo
//   responde con 8 bits que indican, de izquierda a derecha, qué píxeles de
//   esa fila van encendidos (1) y cuáles apagados (0).
// ============================================================================

// Comentario de cabecera original del archivo: describe el tamaño de la ROM
// y cómo se arma la dirección de consulta dentro de ella.
// Font ROM — 256 caracteres × 16 filas × 8 bits por fila
// Dirección: {char_code[7:0], row[3:0]} = 12 bits → 4096 entradas de 8 bits
// Bitmap CP437/IBM PC font
module font_rom (
    // char_code_i: el código ASCII/CP437 del carácter que queremos dibujar
    // (8 bits = hasta 256 caracteres distintos posibles)
    input  logic [7:0] char_code_i,

    // row_i: cuál de las 16 filas del dibujo de ese carácter queremos
    // (4 bits = hasta 16 filas posibles, 0 a 15)
    input  logic [3:0] row_i,

    // pixel_row_o: el resultado de la consulta — 8 bits, uno por cada
    // píxel de esa fila del carácter (1 = píxel encendido/parte de la
    // letra, 0 = píxel apagado/fondo)
    output logic [7:0] pixel_row_o
);
    // ------------------------------------------------------------------
    // "rom" es el banco de memoria: un arreglo con 4096 posiciones (de la
    // 0 a la 4095), donde cada posición guarda 8 bits.
    //
    // ¿De dónde sale el número 4096? Cada uno de los 256 caracteres ocupa
    // 16 filas, y 256 x 16 = 4096. Así que hay exactamente una posición de
    // memoria por cada fila de cada carácter.
    // ------------------------------------------------------------------
    logic [7:0] rom [0:4095];

    // "initial" se ejecuta una sola vez, al "encender" el circuito (o al
    // iniciar la simulación). $readmemh es una instrucción especial que
    // CARGA el contenido de la memoria desde un archivo de texto externo
    // ("font_rom.hex", generado por el script gen_font.py) que contiene los
    // valores en formato hexadecimal. De esta forma no hay que escribir a
    // mano los 4096 valores: se generan aparte y se "graban" en la ROM al
    // sintetizar/cargar el diseño en la FPGA.
    initial $readmemh("font_rom.hex", rom);

    // ------------------------------------------------------------------
    // Esta es la "consulta" en sí. Se arma una dirección de 12 bits
    // concatenando (uniendo) el código del carácter (8 bits) con el
    // número de fila (4 bits): {char_code_i, row_i}.
    //
    // Por ejemplo, para el carácter 65 ('A') y la fila 3, la dirección
    // sería {8'd65, 4'd3}, que ubica exactamente el patrón de bits de la
    // fila 3 del dibujo de la letra 'A' dentro del arreglo "rom".
    //
    // El resultado (8 bits) se entrega de inmediato como pixel_row_o.
    // ------------------------------------------------------------------
    assign pixel_row_o = rom[{char_code_i, row_i}];

endmodule
