// ============================================================================
// QUÉ HACE ESTE ARCHIVO (en palabras simples):
//   La pantalla VGA necesita que le "marquen el ritmo" con una señal que
//   cambia exactamente 25 millones de veces por segundo (25 MHz). A esa señal
//   le llamamos "reloj de píxel". Pero el reloj que trae la placa DE1-SoC es
//   de 50 MHz (50 millones de veces por segundo), el doble de rápido.
//
//   Este módulo es un "reductor de velocidad": toma el reloj de 50 MHz y
//   produce, a partir de él, una señal que cambia a la mitad de esa
//   velocidad, es decir, a 25 MHz. La idea es la misma que usa el diseño de
//   referencia de FPGA Dude (que dividía 100 MHz entre 4 para obtener 25 MHz);
//   aquí, como partimos de 50 MHz, basta con dividir entre 2.
//
//   Sección del documento de diseño relacionada: DISENO.md, apartado 2.5
//   ("generación del reloj de 25 MHz para VGA").
// ============================================================================

// "module" abre la definición de un bloque de hardware llamado vga_clk_gen.
// Entre paréntesis se listan sus "conectores" (puertos): por dónde entra y
// sale información eléctrica hacia/desde otros módulos.
module vga_clk_gen (
    // input  -> esta señal ENTRA al módulo (viene de afuera)
    // logic  -> tipo de dato de SystemVerilog para una señal digital (0 ó 1)
    // clk_50_i -> el reloj del sistema, de 50 MHz (la "i" final es de "input")
    input  logic clk_50_i,

    // rst_i -> señal de "reset" (reinicio). Cuando está en 0, pone el módulo
    // en su estado inicial. Es "activa en bajo": 0 = reiniciar, 1 = funcionar
    // normalmente. Esta convención se usa en todo el proyecto.
    input  logic rst_i,

    // output -> esta señal SALE del módulo hacia quien lo use
    // clk_25_o -> el reloj de píxel resultante, de 25 MHz ("o" de "output")
    output logic clk_25_o
);

    // ------------------------------------------------------------------
    // CÓMO SE OBTIENEN 25 MHz A PARTIR DE 50 MHz:
    //
    // Imagina el reloj de 50 MHz como un interruptor que se enciende y
    // apaga 50 millones de veces por segundo. Si cada vez que ese
    // interruptor "sube" (pasa de 0 a 1) nosotros invertimos el valor de
    // nuestra propia señal de salida (si estaba en 0 la ponemos en 1, y
    // si estaba en 1 la ponemos en 0), el resultado es una nueva señal
    // que completa un ciclo completo (subir y bajar) cada DOS pulsos del
    // reloj original. Eso equivale exactamente a la mitad de la
    // frecuencia: 50 MHz / 2 = 25 MHz. A esto se le llama un "divisor de
    // frecuencia por 2" o "flip-flop en modo conmutador (toggle)".
    // ------------------------------------------------------------------

    // "always_ff" describe un bloque que se ejecuta SOLO en los instantes
    // en que ocurre uno de los eventos indicados entre paréntesis (esto es
    // lo que en hardware se llama un elemento de memoria / registro, que
    // recuerda su valor entre un evento y otro).
    //
    // @(posedge clk_50_i or negedge rst_i):
    //   - "posedge clk_50_i" = en el instante en que el reloj de 50 MHz
    //     pasa de 0 a 1 (flanco de subida)
    //   - "negedge rst_i"    = en el instante en que el reset pasa de 1 a 0
    //     (es decir, cuando se activa el reinicio)
    //   El bloque reacciona a cualquiera de los dos eventos, lo que ocurra
    //   primero.
    always_ff @(posedge clk_50_i or negedge rst_i)

        // Si el reset está activo (recordemos: activo en bajo, o sea valor 0)...
        if (!rst_i)
            // ...ponemos la salida en 0 para arrancar siempre desde un
            // estado conocido. "1'b0" significa "un bit con valor binario 0".
            clk_25_o <= 1'b0;

        // Si NO hay reset (funcionamiento normal)...
        else
            // ...invertimos el valor actual de la salida: el símbolo "~"
            // significa "negación" (invierte 0 por 1 y 1 por 0).
            // Esto hace que la señal "alterne" en cada pulso del reloj de
            // 50 MHz, produciendo así una onda de 25 MHz a la salida.
            // El operador "<=" es una asignación que ocurre de forma
            // sincronizada con el reloj (asignación no bloqueante).
            clk_25_o <= ~clk_25_o;

// "endmodule" cierra la definición del módulo.
endmodule
