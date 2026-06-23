import argparse
import serial
import time

# Configuración de la comunicación UART.
# Debe coincidir con la velocidad usada por el periférico en la FPGA.
BAUD = 115200

# Cantidad de celdas que maneja el área editable de texto.
# Corresponde a 80 columnas por 23 filas.
CELLS = 1840


# Lee desde la FPGA el contenido del editor y lo guarda en un archivo local.
# La FPGA debe iniciar la transferencia enviando SOH para confirmar que está lista.
def save_from_fpga(port: str, output_file: str) -> None:
    # Abre el puerto serial con un timeout para evitar quedarse esperando para siempre.
    with serial.Serial(port, BAUD, timeout=5) as ser:
        print("[INFO] Esperando SOH desde FPGA...")
        b = ser.read(1)

        # SOH marca el inicio de una transferencia desde la FPGA hacia la PC.
        if b != b"\x01":
            raise RuntimeError(f"Se esperaba SOH=0x01, llegó: {b.hex() if b else 'timeout'}")

        data = bytearray()

        # Se leen como máximo las celdas del editor.
        # La lectura también puede terminar antes si llega EOT.
        while len(data) < CELLS:
            b = ser.read(1)

            if not b:
                raise RuntimeError("Timeout esperando datos/EOT desde FPGA")

            # EOT indica que la FPGA terminó de enviar el contenido.
            if b == b"\x04":
                break

            data.extend(b)

        # Guarda exactamente los bytes recibidos, sin intentar convertirlos a texto.
        with open(output_file, "wb") as f:
            f.write(data)

        print(f"[OK] Archivo guardado: {output_file}")
        print(f"[OK] Bytes recibidos: {len(data)}")


# Envía un archivo desde la PC hacia la FPGA para cargarlo en el editor.
# El firmware debe pedir la transferencia enviando ENQ primero.
def load_to_fpga(port: str, input_file: str) -> None:
    # Solo se toman los bytes que caben en el área editable de la pantalla.
    with open(input_file, "rb") as f:
        content = f.read(CELLS)

    # El timeout es un poco mayor porque primero se espera la solicitud del firmware.
    with serial.Serial(port, BAUD, timeout=10) as ser:
        print("[INFO] Esperando ENQ desde FPGA...")
        b = ser.read(1)

        # ENQ significa que la FPGA está solicitando datos desde la PC.
        if b != b"\x05":
            raise RuntimeError(f"Se esperaba ENQ=0x05, llegó: {b.hex() if b else 'timeout'}")

        print("[INFO] Enviando SOH + contenido + EOT...")

        # SOH avisa el inicio del bloque de datos.
        ser.write(b"\x01")
        ser.flush()

        # Pausa pequeña para darle tiempo al firmware a entrar al loop de recepción.
        time.sleep(0.05)

        # Se envía el contenido y luego EOT para marcar el final de la carga.
        ser.write(content)
        ser.write(b"\x04")
        ser.flush()

        print(f"[OK] Archivo enviado: {input_file}")
        print(f"[OK] Bytes enviados: {len(content)}")


# Punto de entrada del programa.
# Permite usar el mismo script para guardar desde la FPGA o cargar hacia la FPGA.
def main() -> None:
    parser = argparse.ArgumentParser(description="Cliente UART para editor RISC-V FPGA")
    parser.add_argument("mode", choices=["save", "load"])
    parser.add_argument("port", help="Ejemplo Windows: COM3 | Linux: /dev/ttyUSB0")
    parser.add_argument("file", help="Archivo de entrada/salida")

    args = parser.parse_args()

    if args.mode == "save":
        save_from_fpga(args.port, args.file)
    else:
        load_to_fpga(args.port, args.file)


if __name__ == "__main__":
    main()
