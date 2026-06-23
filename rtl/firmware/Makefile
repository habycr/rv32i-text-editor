# =============================================================================
# Makefile -- Firmware CE 3201 / RISC-V editor de texto
#
# Este Makefile sirve como una capa simple para no tener que escribir a mano
# los comandos de compilación. Internamente llama a build_rom.py, que ensambla
# el .s, genera el disassembly y produce el rom.hex que usa Quartus/ModelSim.
#
# Uso:
#   make              -> compila editor.s y actualiza rom.hex
#   make editor       -> igual que make; solo compila el firmware principal
#   make tests        -> compila los tests de humo del firmware
#   make all          -> compila editor y tests
#   make clean        -> borra archivos generados por el flujo
# =============================================================================

# Intérprete de Python usado para ejecutar el script de construcción.
PYTHON  := python3

# Script que encapsula ensamblador, linker, objcopy, objdump y generación hex.
BUILD   := $(PYTHON) build_rom.py

# Targets que no representan archivos reales. Se fuerzan como comandos.
.PHONY: all editor tests clean

# Flujo completo: primero firmware principal y luego pruebas.
all: editor tests

# Firmware principal del editor. La dependencia es editor.s.
# Si editor.s cambia, este target vuelve a generar rom.hex.
editor: editor.s
	$(BUILD) editor.s

# Tests de humo. Sirven para verificar casos simples como VGA y UART.
# Se asume que existen en la carpeta tests/.
tests: tests/vga_hello.s tests/uart_tx_test.s
	$(BUILD) tests/vga_hello.s
	$(BUILD) tests/uart_tx_test.s

# Limpieza de archivos intermedios/generados por el flujo de firmware.
# No borra editor.s ni los fuentes de tests.
clean:
	rm -f *.o *.elf *.bin *.dump *_link.ld rom.hex
	rm -f tests/*.o tests/*.elf tests/*.bin tests/*.dump tests/*_link.ld tests/rom.hex
