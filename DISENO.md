# DISENO.md — Microcontrolador RISC-V RV32I con Procesador de Texto

**Curso:** CE 3201 Taller de Diseño Digital — I Semestre 2026  
**Proyecto:** Microcontrolador RISC-V con procesador de texto  
**Equipo:** <!-- Nombres de los integrantes -->  
**Fecha:** <!-- Fecha de última actualización -->  
**Repositorio:** <!-- URL del repositorio GitLab -->

> Este documento debe completarse **antes de escribir cualquier línea de código HDL**.  
> Consulta `docs/guia_visual.md` para convenciones de diagramación y `docs/img/README.md` para nombres de archivos de imagen.

---

## 1. Metodología de diseño top-down

### 1.1 Descripción de la jerarquía de módulos

<!-- Explica brevemente cómo se aplicó el diseño modular top-down al sistema.
     Describe los niveles de jerarquía (nivel 1 → nivel 4) y por qué se eligió esa descomposición. -->

### 1.2 Criterios de descomposición modular

<!-- Describe los criterios usados para dividir el sistema en módulos:
     - Separación de responsabilidades (CPU, memoria, periféricos)
     - Independencia de interfaces
     - Reutilización y verificabilidad independiente
     - Coherencia con el mapa de memoria -->

---

## 2. Sistema completo integrado

### 2.1 Diagrama de nivel 1 — Vista de caja negra

<!-- Inserta la imagen: docs/img/nivel1_sistema.png -->

**Objetivo:** <!-- Qué resuelve el sistema completo -->

**Entradas:**

| Señal | Ancho | Función |
|-------|-------|---------|
| `clk_i` | 1 bit | Reloj principal del sistema (50 MHz) |
| `rst_i` | 1 bit | Reset activo en bajo |
| `uart_rx_i` | 1 bit | Línea de recepción UART desde PC |
| `ps2_clk_i` | 1 bit | Reloj del protocolo PS/2 |
| `ps2_data_i` | 1 bit | Datos del protocolo PS/2 |

**Salidas:**

| Señal | Ancho | Función |
|-------|-------|---------|
| `uart_tx_o` | 1 bit | Línea de transmisión UART hacia PC |
| `vga_hsync_o` | 1 bit | Sincronía horizontal VGA |
| `vga_vsync_o` | 1 bit | Sincronía vertical VGA |
| `vga_r_o` | 4 bits | Canal rojo VGA (paleta CGA) |
| `vga_g_o` | 4 bits | Canal verde VGA (paleta CGA) |
| `vga_b_o` | 4 bits | Canal azul VGA (paleta CGA) |

**Explicación general:**  
<!-- Describe en 2–3 oraciones qué hace el sistema completo desde la perspectiva del usuario -->

---

### 2.2 Diagrama de nivel 2 — Subsistemas internos

<!-- Inserta la imagen: docs/img/nivel2_sistema.png -->

**Explicación general del sistema:**  
<!-- Describe cómo interactúan los subsistemas entre sí -->

#### 2.2.1 CPU (RISC-V RV32I)

**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Explicación general:**  

#### 2.2.2 Memoria ROM

**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Explicación general:**  

#### 2.2.3 Memoria RAM

**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Explicación general:**  

#### 2.2.4 UART

**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Explicación general:**  

#### 2.2.5 PS/2

**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Explicación general:**  

#### 2.2.6 Timer

**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Explicación general:**  

#### 2.2.7 Controlador VGA

**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Explicación general:**  

---

### 2.3 Mapa de conexiones CPU – memorias – periféricos

<!-- Inserta la imagen: docs/img/mapa_conexiones.png -->

<!-- Describe brevemente los buses principales: bus de instrucciones, bus de datos y bus de periféricos -->

---

### 2.4 Mapa de memoria

| Región | Inicio | Fin | Tamaño | Descripción |
|--------|--------|-----|--------|-------------|
| ROM (programa) | `0x0000_0000` | `0x0000_1FFF` | 8 KB | Almacena el firmware en ensamblador RV32I. Vector de reset en `0x0000_0000`. |
| RAM (datos) | `0x0000_2000` | `0x0000_2FFF` | 4 KB | Memoria de datos de lectura/escritura |
| Espacio de periféricos | `0x0001_0000` | `0x0001_FFFF` | 64 KB | Registros de control/estado/datos de periféricos |

#### Registros de periféricos

| Periférico | Registro | Offset | Dirección absoluta |
|-----------|----------|--------|--------------------|
| UART | Control/Estado | `0x00` | `0x0001_0040` |
| UART | Datos TX | `0x04` | `0x0001_0044` |
| UART | Datos RX | `0x08` | `0x0001_0048` |
| PS/2 | Control/Estado | `0x00` | `0x0001_0050` |
| PS/2 | RX | `0x04` | `0x0001_0054` |
| PS/2 | TX | `0x08` | `0x0001_0058` |
| Timer | Control/Estado | `0x00` | `0x0001_0060` |
| Timer | Datos | `0x04` | `0x0001_0064` |
| VGA | Control/Cursor | `0x00` | `0x0001_0120` |
| VGA | Buffer de texto (80×24) | — | `0x0001_1000` – `0x0001_2DFF` |

---

### 2.5 Diagrama de nivel 3 del sistema — Integración con decodificador

<!-- Inserta la imagen: docs/img/nivel3_sistema.png -->

<!-- Describe el decodificador de direcciones, las señales de chip select (CS) por módulo
     y la generación del reloj de 25 MHz para VGA -->

---

## 3. CPU RISC-V RV32I

### 3.1 Diagrama de bloques — Nivel 3

<!-- Inserta la imagen: docs/img/cpu_nivel3.png -->

<!-- Describe los bloques funcionales: PC, banco de registros, unidad de instrucción/decodificación,
     ALU, unidad de control, extensión de signo, MUXes de selección -->

### 3.2 Ruta de datos (datapath)

<!-- Inserta la imagen: docs/img/cpu_datapath.png -->

<!-- Describe el flujo de señales para al menos 3 tipos de instrucción: tipo-R, load/store, branch -->

### 3.3 FSM de la unidad de control

<!-- Inserta la imagen: docs/img/cpu_control_fsm.png -->

<!-- Describe los estados, condiciones de transición y señales de control emitidas en cada estado -->

### 3.4 Tabla de señales de control por tipo de instrucción

| Instrucción | Tipo | RegWrite | MemRead | MemWrite | Branch | ALUSrc | ALUOp |
|-------------|------|----------|---------|----------|--------|--------|-------|
| `add` | R | 1 | 0 | 0 | 0 | 0 | <!-- --> |
| `addi` | I | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> |
| `lw` | I | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> |
| `sw` | S | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> |
| `beq` | B | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> |
| `jal` | J | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> | <!-- --> |

### 3.5 Tabla de instrucciones RV32I implementadas

| Mnemónico | Tipo | opcode [6:0] | funct3 [2:0] | funct7 [6:0] | Descripción |
|-----------|------|-------------|-------------|-------------|-------------|
| `lw` | I | `0000011` | `010` | — | Carga palabra desde memoria |
| `sw` | S | `0100011` | `010` | — | Almacena palabra en memoria |
| `add` | R | `0110011` | `000` | `0000000` | Suma de registros |
| `sub` | R | `0110011` | `000` | `0100000` | Resta de registros |
| `and` | R | `0110011` | `111` | `0000000` | AND lógico |
| `or` | R | `0110011` | `110` | `0000000` | OR lógico |
| `xor` | R | `0110011` | `100` | `0000000` | XOR lógico |
| `sll` | R | `0110011` | `001` | `0000000` | Desplazamiento lógico izquierda |
| `srl` | R | `0110011` | `101` | `0000000` | Desplazamiento lógico derecha |
| `sra` | R | `0110011` | `101` | `0100000` | Desplazamiento aritmético derecha |
| `slt` | R | `0110011` | `010` | `0000000` | Set if less than (signed) |
| `sltu` | R | `0110011` | `011` | `0000000` | Set if less than (unsigned) |
| `addi` | I | `0010011` | `000` | — | Suma inmediato |
| `andi` | I | `0010011` | `111` | — | AND con inmediato |
| `ori` | I | `0010011` | `110` | — | OR con inmediato |
| `xori` | I | `0010011` | `100` | — | XOR con inmediato |
| `slli` | I | `0010011` | `001` | `0000000` | Desplazamiento lógico izq. inmediato |
| `srli` | I | `0010011` | `101` | `0000000` | Desplazamiento lógico der. inmediato |
| `srai` | I | `0010011` | `101` | `0100000` | Desplazamiento aritmético der. inmediato |
| `slti` | I | `0010011` | `010` | — | Set if less than inmediato (signed) |
| `sltui` | I | `0010011` | `011` | — | Set if less than inmediato (unsigned) |
| `beq` | B | `1100011` | `000` | — | Branch if equal |
| `bne` | B | `1100011` | `001` | — | Branch if not equal |
| `blt` | B | `1100011` | `100` | — | Branch if less than |
| `bge` | B | `1100011` | `101` | — | Branch if greater or equal |
| `jal` | J | `1101111` | — | — | Jump and link |
| `jalr` | I | `1100111` | `000` | — | Jump and link register |

### 3.6 Nivel 4 — Fichas de módulos del CPU

#### 3.6.1 Contador de Programa (PC)

**Nombre:** `program_counter`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 3.6.2 Banco de Registros

**Nombre:** `register_file`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 3.6.3 Unidad Aritmético-Lógica (ALU)

**Nombre:** `alu`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 3.6.4 Unidad de Control

**Nombre:** `control_unit`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 3.6.5 Extensión de Signo

**Nombre:** `sign_extend`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

---

## 4. Periférico UART

### 4.1 Diagrama de bloques — Nivel 3

![Diagrama de nivel 3 del periférico UART](docs/img/uart_n3.png)

**Figura 4.1.** Diagrama de nivel 3 del periférico UART 115200-8N1.

El periférico UART se descompone en tres bloques principales: la interfaz de bus `uart_bus_if`, el banco de registros mapeados en memoria y el núcleo UART 115200-8N1. Esta división permite separar la comunicación con el bus del sistema, el almacenamiento de datos/control visible por software y la lógica serial encargada de transmitir y recibir tramas UART.

El módulo `uart_bus_if` recibe los accesos provenientes del bus de interconexión de Dylan mediante las señales `addr[31:0]`, `wdata[31:0]`, `we`, `re` y `cs_uart`. A partir de estas señales, genera operaciones internas de lectura y escritura sobre los registros UART. Cuando el procesador lee el periférico, la interfaz responde hacia el bus mediante `uart_rdata[31:0]` y `uart_ready`.

Los registros mapeados en memoria del UART son `CTRL/STATUS`, `TXDATA` y `RXDATA`. El registro `CTRL/STATUS`, ubicado en `0x0001_0040`, concentra señales de habilitación, control y estado del periférico. El registro `TXDATA`, ubicado en `0x0001_0044`, almacena el byte que será transmitido por el bloque `UART TX`. El registro `RXDATA`, ubicado en `0x0001_0048`, almacena el byte recibido por el bloque `UART RX`.

El núcleo UART implementa la comunicación serial con configuración 115200-8N1, es decir, 115200 baudios, 8 bits de datos, sin paridad y 1 bit de parada. Internamente se divide en tres submódulos: `UART RX`, `Baud generator` y `UART TX`. El `Baud generator` deriva los pulsos de temporización a partir del reloj de 50 MHz, usando aproximadamente 434 ciclos por bit para la tasa de 115200 baudios. El bloque `UART RX` recibe la señal externa `uart_rx_i`, detecta la trama serial y entrega `rx_data[7:0]`, `rx_ready` y `rx_error`. El bloque `UART TX` toma `tx_data[7:0]` y `tx_start`, genera la trama serial correspondiente y entrega la salida externa `uart_tx_o`.

La conexión entre registros y núcleo UART permite que el software controle la transmisión, consulte el estado del periférico y lea los datos recibidos. En particular, `CTRL/STATUS` recibe los estados `rx_ready`, `rx_error`, `tx_busy` y `tx_ready`; `TXDATA` alimenta al transmisor mediante `tx_data[7:0]` y `tx_start`; y `RXDATA` recibe el byte entregado por el receptor. Con esta organización, el UART queda integrado como periférico mapeado en memoria y mantiene una interfaz coherente con el bus del sistema.

**Submódulos representados en el nivel 3:**

| Bloque | Función |
|--------|---------|
| `uart_bus_if` | Traduce accesos del bus del sistema en operaciones de lectura/escritura sobre los registros UART. |
| `CTRL/STATUS` | Registro de control y estado del periférico UART. Permite habilitar TX/RX, limpiar banderas y consultar estados. |
| `TXDATA` | Registro que almacena el byte que será transmitido por el UART. |
| `RXDATA` | Registro que almacena el byte recibido por el UART. |
| `Baud generator` | Genera los pulsos de temporización `baud_tick` y `sample_tick` para TX y RX. |
| `UART TX` | Construye y transmite la trama serial UART: start, 8 bits de datos y stop. |
| `UART RX` | Recibe la trama serial UART, reconstruye el byte recibido y genera señales de estado/error. |

**Conexiones principales del nivel 3:**

| Origen | Destino | Señales |
|--------|---------|---------|
| Bus e interconexión | `uart_bus_if` | `addr[31:0]`, `wdata[31:0]`, `we`, `re`, `cs_uart` |
| `uart_bus_if` | Bus e interconexión | `uart_rdata[31:0]`, `uart_ready` |
| `uart_bus_if` | `CTRL/STATUS` | `wr_ctrl`, `rd_status` |
| `uart_bus_if` | `TXDATA` | `wr_tx_data[7:0]` |
| `RXDATA` | `uart_bus_if` | `rd_rx_data[7:0]` |
| `CTRL/STATUS` | Núcleo UART | `tx_enable`, `rx_enable`, `clear_flags` |
| `TXDATA` | `UART TX` | `tx_data[7:0]`, `tx_start` |
| `UART RX` | `RXDATA` | `rx_data[7:0]` |
| `UART RX` | `CTRL/STATUS` | `rx_ready`, `rx_error` |
| `UART TX` | `CTRL/STATUS` | `tx_busy`, `tx_ready` |
| `Baud generator` | `UART TX` | `baud_tick` |
| `Baud generator` | `UART RX` | `sample_tick` |
| `uart_rx_i` | `UART RX` | `serial RX` |
| `UART TX` | `uart_tx_o` | `serial TX` |

### 4.2 FSM del UART

<!-- Inserta la imagen: docs/img/uart_fsm.png -->

### 4.3 Tabla de interfaz de puertos

| Puerto | Dirección | Ancho | Función |
|--------|-----------|-------|---------|
| `clk_i` | Entrada | 1 bit | Reloj del sistema (50 MHz) |
| `rst_i` | Entrada | 1 bit | Reset activo en bajo |
| `tx_data_i` | Entrada | 8 bits | Byte a transmitir |
| `tx_start_i` | Entrada | 1 bit | Inicia transmisión |
| `rx_i` | Entrada | 1 bit | Línea serial de recepción |
| `tx_o` | Salida | 1 bit | Línea serial de transmisión |
| `tx_ready_o` | Salida | 1 bit | Transmisor libre |
| `rx_ready_o` | Salida | 1 bit | Byte recibido disponible |
| `rx_data_o` | Salida | 8 bits | Byte recibido |

### 4.4 Nivel 4 — Fichas de módulos del UART

#### 4.4.1 Generador de baud rate

**Nombre:** `baud_gen`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:** Divisor de frecuencia: ⌊50 000 000 / 115 200⌋ = 434 ciclos por bit.  
**Justificación de diseño:**  

#### 4.4.2 Transmisor UART (TX)

**Nombre:** `uart_tx`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 4.4.3 Receptor UART (RX)

**Nombre:** `uart_rx`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

---

## 5. Periférico PS/2

### 5.1 Diagrama de bloques — Nivel 3

![Diagrama de nivel 3 del periférico PS/2](docs/img/ps2_n3.png)

**Figura 5.1.** Diagrama de nivel 3 del periférico PS/2.

El periférico PS/2 se descompone en una interfaz de bus `ps2_bus_if`, un banco de registros mapeados en memoria y un núcleo PS/2 encargado de la recepción de scancodes y la transmisión de comandos hacia el teclado. Esta división mantiene separada la comunicación con el bus del sistema, el almacenamiento visible por software y la lógica propia del protocolo PS/2.

El módulo `ps2_bus_if` recibe los accesos provenientes del bus de interconexión mediante las señales `addr[31:0]`, `wdata[31:0]`, `we`, `re` y `cs_ps2`. A partir de estas señales, genera operaciones internas de lectura y escritura sobre los registros del periférico. Cuando el procesador lee el periférico, la interfaz responde hacia el bus mediante `ps2_rdata[31:0]` y `ps2_ready`.

Los registros mapeados en memoria del PS/2 son `CTRL/STATUS`, `RXDATA` y `TXDATA`. El registro `CTRL/STATUS`, ubicado en `0x0001_0050`, concentra las señales de control y estado del periférico, incluyendo `rx_ready`, `tx_ready`, `rx_error`, `tx_error` y `kbd_enable`. El registro `RXDATA`, ubicado en `0x0001_0054`, almacena el scancode recibido desde el teclado. El registro `TXDATA`, ubicado en `0x0001_0058`, almacena el comando que será enviado hacia el teclado mediante el transmisor PS/2.

El núcleo PS/2 recibe las señales externas `ps2_clk_i` y `ps2_data_i`. La entrada de reloj y datos pasa primero por un sincronizador y detector de flanco, el cual genera señales internas sincronizadas y detecta el flanco descendente del reloj PS/2. La FSM de recepción controla el proceso de captura de bits, avanzando por los estados `IDLE`, `SHIFT`, `CHECK`, `DONE` y `ERROR`. El receptor de trama captura la estructura de 11 bits del protocolo PS/2: bit de inicio, 8 bits de datos LSB-first, bit de paridad y bit de parada.

Después de recibir la trama, el verificador de paridad y stop valida la paridad impar y el bit de parada. Si la trama es válida, el byte recibido se entrega al bloque de manejo de prefijos. Este bloque identifica los prefijos `0xF0`, usado para códigos de liberación de tecla, y `0xE0`, usado para teclas extendidas. Las señales internas `is_break` e `is_extended` se utilizan dentro del núcleo para que el decodificador de scancodes interprete correctamente el byte recibido; no se exponen como bits visibles del registro `CTRL/STATUS`.

El decodificador de scancodes Set 2 convierte el byte recibido y sus prefijos asociados en un scancode disponible para el sistema. Cuando existe un dato válido, se genera `rx_ready` hacia `CTRL/STATUS` y se escribe `scancode[7:0]` hacia `RXDATA`. En caso de error de paridad o enmarcado, el verificador genera `rx_error` hacia `CTRL/STATUS`.

El bloque de transmisión de comandos PS/2 permite enviar comandos desde el microcontrolador hacia el teclado. Este bloque toma `tx_data[7:0]` y `tx_start` desde `TXDATA`, genera la trama PS/2 correspondiente y controla las señales externas `ps2_clk_o` y `ps2_data_o` para transmisión. También reporta `tx_ready` y `tx_error` hacia `CTRL/STATUS`.

**Submódulos representados en el nivel 3:**

| Bloque                             | Función                                                                                                                                                   |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ps2_bus_if`                       | Traduce accesos del bus del sistema en operaciones de lectura/escritura sobre los registros PS/2.                                                         |
| `CTRL/STATUS`                      | Registro de control y estado del periférico. Contiene banderas como `rx_ready`, `tx_ready`, `rx_error`, `tx_error` y el bit de habilitación `kbd_enable`. |
| `RXDATA`                           | Registro que almacena el scancode recibido desde el teclado.                                                                                              |
| `TXDATA`                           | Registro que almacena el comando que se enviará hacia el teclado.                                                                                         |
| Sincronizador y detector de flanco | Sincroniza `ps2_clk_i` y `ps2_data_i` al reloj del sistema y detecta el flanco descendente del reloj PS/2.                                                |
| FSM de recepción                   | Controla el proceso de recepción de la trama PS/2 mediante los estados `IDLE`, `SHIFT`, `CHECK`, `DONE` y `ERROR`.                                        |
| Receptor de trama de 11 bits       | Captura la trama PS/2 formada por start, 8 bits de datos, paridad y stop, en orden LSB-first.                                                             |
| Verificador de paridad y stop      | Valida la paridad impar y el bit de parada de la trama recibida.                                                                                          |
| Manejo de prefijos                 | Detecta los prefijos `0xF0` para break code y `0xE0` para teclas extendidas.                                                                              |
| Decodificador de scancodes Set 2   | Interpreta el byte recibido y los prefijos internos para producir el scancode final.                                                                      |
| Transmisor de comandos PS/2        | Envía comandos hacia el teclado y reporta estado de transmisión mediante `tx_ready` y `tx_error`.                                                         |

**Conexiones principales del nivel 3:**

| Origen                             | Destino                            | Señales                                           |
| ---------------------------------- | ---------------------------------- | ------------------------------------------------- |
| Bus e interconexión                | `ps2_bus_if`                       | `addr[31:0]`, `wdata[31:0]`, `we`, `re`, `cs_ps2` |
| `ps2_bus_if`                       | Bus e interconexión                | `ps2_rdata[31:0]`, `ps2_ready`                    |
| `ps2_bus_if`                       | `CTRL/STATUS`                      | `wr_ctrl`, `rd_status`                            |
| `ps2_bus_if`                       | `TXDATA`                           | `wr_tx_data[7:0]`                                 |
| `RXDATA`                           | `ps2_bus_if`                       | `rd_rx_data[7:0]`                                 |
| `CTRL/STATUS`                      | FSM de recepción                   | `kbd_enable`, `clear_flags`                       |
| `ps2_clk_i`                        | Sincronizador y detector de flanco | `reloj PS/2`                                      |
| `ps2_data_i`                       | Sincronizador y detector de flanco | `datos PS/2`                                      |
| Sincronizador y detector de flanco | FSM de recepción                   | `fall_edge`, `ps2_data_sync`                      |
| FSM de recepción                   | Receptor de trama de 11 bits       | `bit_shift`, `bit_count`                          |
| Receptor de trama de 11 bits       | Verificador de paridad y stop      | `frame[10:0]`, `rx_byte[7:0]`                     |
| Verificador de paridad y stop      | Manejo de prefijos                 | `frame_ok`, `parity_ok`                           |
| Verificador de paridad y stop      | `CTRL/STATUS`                      | `rx_error`                                        |
| Manejo de prefijos                 | Decodificador de scancodes Set 2   | `rx_byte[7:0]`, `is_break`, `is_extended`         |
| Decodificador de scancodes Set 2   | `RXDATA`                           | `scancode[7:0]`                                   |
| Decodificador de scancodes Set 2   | `CTRL/STATUS`                      | `rx_ready`                                        |
| `TXDATA`                           | Transmisor de comandos PS/2        | `tx_data[7:0]`, `tx_start`                        |
| Transmisor de comandos PS/2        | `CTRL/STATUS`                      | `tx_ready`, `tx_error`                            |
| Transmisor de comandos PS/2        | `ps2_clk_o`                        | `ps2_clk_drive`                                   |
| Transmisor de comandos PS/2        | `ps2_data_o`                       | `ps2_data_drive`                                  |


### 5.2 FSM del PS/2

<!-- Inserta la imagen: docs/img/ps2_fsm.png -->

### 5.3 Tabla de interfaz de puertos

| Puerto | Dirección | Ancho | Función |
|--------|-----------|-------|---------|
| `clk_i` | Entrada | 1 bit | Reloj del sistema |
| `rst_i` | Entrada | 1 bit | Reset activo en bajo |
| `ps2_clk_i` | Entrada | 1 bit | Reloj PS/2 del teclado |
| `ps2_data_i` | Entrada | 1 bit | Datos PS/2 del teclado |
| `kbd_enable_i` | Entrada | 1 bit | Habilita recepción |
| `tx_data_i` | Entrada | 8 bits | Comando a enviar al teclado |
| `rx_ready_o` | Salida | 1 bit | Scancode disponible |
| `rx_data_o` | Salida | 8 bits | Byte de scancode recibido |
| `tx_ready_o` | Salida | 1 bit | Transmisor libre |
| `rx_error_o` | Salida | 1 bit | Error de paridad o enmarcado |
| `ps2_clk_o` | Salida | 1 bit | Reloj PS/2 (para TX) |
| `ps2_data_o` | Salida | 1 bit | Datos PS/2 (para TX) |

### 5.4 Nivel 4 — Fichas de módulos del PS/2

#### 5.4.1 Receptor PS/2

**Nombre:** `ps2_rx`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:** Captura los 11 bits de la trama PS/2 (start, 8 datos LSB-first, paridad impar, stop) en flanco descendente de `ps2_clk_i`. Verifica paridad. Maneja prefijos 0xF0 (break) y 0xE0 (extendida).  
**Justificación de diseño:**  

#### 5.4.2 Transmisor PS/2

**Nombre:** `ps2_tx`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

---

## 6. Periférico Timer

### 6.1 Diagrama de bloques — Nivel 3

<!-- Inserta la imagen: docs/img/timer_nivel3.png -->

### 6.2 FSM del Timer

<!-- Inserta la imagen -->

### 6.3 Tabla de interfaz de puertos

| Puerto | Dirección | Ancho | Función |
|--------|-----------|-------|---------|
| `clk_i` | Entrada | 1 bit | Reloj del sistema |
| `rst_i` | Entrada | 1 bit | Reset activo en bajo |
| `start_i` | Entrada | 1 bit | Habilita el conteo |
| `stop_i` | Entrada | 1 bit | Detiene el conteo |
| `clear_i` | Entrada | 1 bit | Reinicia al valor inicial |
| `autoreload_i` | Entrada | 1 bit | Habilita recarga automática |
| `load_val_i` | Entrada | 32 bits | Valor inicial del contador |
| `timeout_o` | Salida | 1 bit | Indica que el contador llegó a 0 |
| `count_o` | Salida | 32 bits | Valor actual del contador |

### 6.4 Nivel 4 — Fichas de módulos del Timer

#### 6.4.1 Contador de 32 bits

**Nombre:** `timer_counter`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

---

## 7. Controlador VGA

### 7.1 Diagrama de bloques — Nivel 3

<!-- Inserta la imagen: docs/img/vga_nivel3.png -->

### 7.2 Diagrama de timing VGA 640×480 @ 60 Hz

<!-- Inserta la imagen: docs/img/vga_timing.png -->

| Parámetro | Horizontal (píxeles) | Vertical (líneas) |
|-----------|---------------------|-------------------|
| Región activa | 640 | 480 |
| Front porch | 16 | 10 |
| Sync pulse | 96 | 2 |
| Back porch | 48 | 33 |
| **Total** | **800** | **525** |

Reloj de píxel: 25 MHz (generado por divisor de frecuencia o PLL desde 50 MHz).

### 7.3 Formato del buffer de texto

<!-- Inserta la imagen: docs/img/vga_text_mode.png -->

- Resolución en texto: 80 columnas × 24 filas
- Tamaño de glifo: 8×16 píxeles (Font ROM interna)
- Dirección de celda (col, fila): `0x0001_1000 + (fila × 80 + col) × 4`

| Bits | Campo | Descripción |
|------|-------|-------------|
| [7:0] | ASCII | Código ASCII del carácter a mostrar |
| [11:8] | Color frente | Paleta CGA de 4 bits |
| [15:12] | Color fondo | Paleta CGA de 4 bits |
| [31:16] | Reservado | Leer como 0, escrituras ignoradas |

### 7.4 Tabla de interfaz de puertos

| Puerto | Dirección | Ancho | Función |
|--------|-----------|-------|---------|
| `clk_25_i` | Entrada | 1 bit | Reloj de píxel (25 MHz) |
| `rst_i` | Entrada | 1 bit | Reset activo en bajo |
| `addr_i` | Entrada | 32 bits | Dirección de celda del buffer |
| `data_i` | Entrada | 32 bits | Dato a escribir en buffer |
| `we_i` | Entrada | 1 bit | Habilitación de escritura |
| `cursor_col_i` | Entrada | 7 bits | Columna del cursor (0–79) |
| `cursor_row_i` | Entrada | 5 bits | Fila del cursor (0–23) |
| `blink_en_i` | Entrada | 1 bit | Habilita parpadeo del cursor |
| `hsync_o` | Salida | 1 bit | Sincronía horizontal |
| `vsync_o` | Salida | 1 bit | Sincronía vertical |
| `r_o` | Salida | 4 bits | Canal rojo |
| `g_o` | Salida | 4 bits | Canal verde |
| `b_o` | Salida | 4 bits | Canal azul |

### 7.5 Nivel 4 — Fichas de módulos del controlador VGA

#### 7.5.1 Generador de timing H/V

**Nombre:** `vga_timing_gen`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 7.5.2 Lógica de acceso al buffer de texto

**Nombre:** `text_buffer`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 7.5.3 Font ROM

**Nombre:** `font_rom`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

#### 7.5.4 Paleta CGA y lógica de color

**Nombre:** `cga_palette`  
**Objetivo:**  
**Entradas:**  
**Salidas:**  
**Relación con otros módulos:**  
**Funcionamiento:**  
**Justificación de diseño:**  

---

## 8. Firmware — Editor de texto

### 8.1 Diagrama de flujo: Inicialización del sistema

<!-- Inserta la imagen: docs/img/fw_init.png -->

### 8.2 FSM de modos del editor

<!-- Inserta la imagen: docs/img/fw_editor_fsm.png -->

### 8.3 Diagrama de flujo: Bucle principal

<!-- Inserta la imagen: docs/img/fw_main_loop.png -->

### 8.4 Diagrama de flujo: Manejador de teclado PS/2

<!-- Inserta la imagen: docs/img/fw_ps2_handler.png -->

### 8.5 Diagrama de flujo: Actualización del buffer VGA

<!-- Incluido dentro del manejador de teclado o como diagrama separado -->

### 8.6 Diagrama de flujo: Protocolo UART (guardar/cargar)

<!-- Inserta la imagen: docs/img/fw_uart_protocol.png -->

---

## 9. Estrategia de verificación

### 9.1 CPU

| # | Señales de entrada | Comportamiento esperado | Criterio pass/fail | Testbench |
|---|--------------------|------------------------|--------------------|-----------|
| 1 | <!-- --> | <!-- --> | <!-- --> | `tb_cpu.sv` |
| 2 | <!-- --> | <!-- --> | <!-- --> | `tb_cpu.sv` |
| 3 | <!-- --> | <!-- --> | <!-- --> | `tb_cpu.sv` |

### 9.2 UART

| # | Señales de entrada | Comportamiento esperado | Criterio pass/fail | Testbench |
|---|--------------------|------------------------|--------------------|-----------|
| 1 | <!-- --> | <!-- --> | <!-- --> | `tb_uart.sv` |
| 2 | <!-- --> | <!-- --> | <!-- --> | `tb_uart.sv` |
| 3 | <!-- --> | <!-- --> | <!-- --> | `tb_uart.sv` |

### 9.3 PS/2

| # | Señales de entrada | Comportamiento esperado | Criterio pass/fail | Testbench |
|---|--------------------|------------------------|--------------------|-----------|
| 1 | <!-- --> | <!-- --> | <!-- --> | `tb_ps2.sv` |
| 2 | <!-- --> | <!-- --> | <!-- --> | `tb_ps2.sv` |
| 3 | <!-- --> | <!-- --> | <!-- --> | `tb_ps2.sv` |

### 9.4 Timer

| # | Señales de entrada | Comportamiento esperado | Criterio pass/fail | Testbench |
|---|--------------------|------------------------|--------------------|-----------|
| 1 | <!-- --> | <!-- --> | <!-- --> | `tb_timer.sv` |
| 2 | <!-- --> | <!-- --> | <!-- --> | `tb_timer.sv` |
| 3 | <!-- --> | <!-- --> | <!-- --> | `tb_timer.sv` |

### 9.5 VGA

| # | Señales de entrada | Comportamiento esperado | Criterio pass/fail | Testbench |
|---|--------------------|------------------------|--------------------|-----------|
| 1 | <!-- --> | <!-- --> | <!-- --> | `tb_vga.sv` |
| 2 | <!-- --> | <!-- --> | <!-- --> | `tb_vga.sv` |
| 3 | <!-- --> | <!-- --> | <!-- --> | `tb_vga.sv` |

---

## 10. Tabla de asignación de pines FPGA DE10-Standard

| Señal del diseño | Dirección | Pin físico FPGA | Estándar I/O | Comentario |
|-----------------|-----------|----------------|--------------|------------|
| `clk_i` | Entrada | <!-- --> | 3.3V LVTTL | Oscilador de 50 MHz |
| `rst_i` | Entrada | <!-- --> | 3.3V LVTTL | KEY[0] activo en bajo |
| `uart_rx_i` | Entrada | <!-- --> | 3.3V LVTTL | GPIO o conector USB-UART |
| `uart_tx_o` | Salida | <!-- --> | 3.3V LVTTL | GPIO o conector USB-UART |
| `ps2_clk_i` | Entrada | <!-- --> | 3.3V LVTTL | Conector PS/2 |
| `ps2_data_i` | Entrada | <!-- --> | 3.3V LVTTL | Conector PS/2 |
| `vga_hsync_o` | Salida | <!-- --> | 3.3V LVTTL | Conector VGA |
| `vga_vsync_o` | Salida | <!-- --> | 3.3V LVTTL | Conector VGA |
| `vga_r_o[3:0]` | Salida | <!-- --> | 3.3V LVTTL | Canal rojo VGA |
| `vga_g_o[3:0]` | Salida | <!-- --> | 3.3V LVTTL | Canal verde VGA |
| `vga_b_o[3:0]` | Salida | <!-- --> | 3.3V LVTTL | Canal azul VGA |

---

## 11. Alternativas de diseño

### 11.1 CPU: Uniciclo vs. Multiciclo

<!-- Inserta la imagen: docs/img/alt_cpu_unic_vs_multic.png -->

| Criterio | Uniciclo | Multiciclo |
|----------|----------|------------|
| CPI | 1 (siempre) | Variable (promedio < 1 uniciclo para instrucciones simples) |
| Complejidad de la unidad de control | Baja (lógica combinacional) | Alta (FSM de varios estados) |
| Uso de recursos (LUTs) | <!-- --> | <!-- --> |
| Latencia por instrucción | Limitada por la instrucción más lenta | Proporcional a la instrucción |
| Facilidad de verificación | Alta | Media |

**Alternativa seleccionada:** <!-- Uniciclo / Multiciclo -->  
**Justificación:** <!-- -->

### 11.2 Controlador PS/2: Alternativas

<!-- Inserta la imagen: docs/img/alt_ps2.png -->

| Criterio | FSM clásica | Contador de bits con shift register |
|----------|-------------|-------------------------------------|
| Complejidad | <!-- --> | <!-- --> |
| Uso de recursos | <!-- --> | <!-- --> |
| Manejo de errores | <!-- --> | <!-- --> |

**Alternativa seleccionada:** <!-- -->  
**Justificación:** <!-- -->

### 11.3 Renderizado VGA: Alternativas

<!-- Inserta la imagen: docs/img/alt_vga.png -->

| Criterio | Modo texto con Font ROM | Modo bitmap |
|----------|------------------------|-------------|
| Uso de memoria | <!-- --> | <!-- --> |
| Complejidad de la lógica de renderizado | <!-- --> | <!-- --> |
| Flexibilidad visual | <!-- --> | <!-- --> |

**Alternativa seleccionada:** <!-- -->  
**Justificación:** <!-- -->