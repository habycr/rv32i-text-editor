#!/usr/bin/env python3
"""
build_rom.py  --  Ensambla un archivo .s para el microcontrolador RISC-V
                  del proyecto CE 3201 y genera rom.hex compatible con
                  $readmemh.

Uso:
    python3 build_rom.py firmware/editor.s
    python3 build_rom.py firmware/tests/vga_hello.s
    python3 build_rom.py firmware/tests/uart_tx_test.s

Salidas (en el mismo directorio que el .s):
    <base>.elf
    <base>.dump        (disassembly)
    <base>.bin         (binario plano, little-endian)
    rom.hex            (2048 palabras de 32 bits para $readmemh)

Requisitos:
    riscv64-unknown-elf-as  (o riscv32-unknown-elf-as)
    riscv64-unknown-elf-ld
    riscv64-unknown-elf-objcopy
    riscv64-unknown-elf-objdump
    Python >= 3.6

Detección automática del prefijo del toolchain:
    Prueba primero 'riscv32-unknown-elf-', luego 'riscv64-unknown-elf-'.
"""

import sys
import os
import subprocess
import struct

# Nota:
#   Este archivo está pensado para ser ejecutado desde la carpeta de firmware.
#   No modifica el ensamblador; solo automatiza el flujo de construcción y
#   verifica que el binario final no use instrucciones fuera del RV32I soportado.
#

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------
ROM_WORDS   = 2048          # capacidad de la ROM en palabras de 32 bits
NOP_WORD    = 0x00000013    # addi x0, x0, 0 (relleno)
TEXT_START  = 0x00000000    # dirección donde arranca .text

# Instrucciones prohibidas en el ISA de este CPU
FORBIDDEN_MNEMONICS = {
    "mul", "mulh", "mulhsu", "mulhu",
    "div", "divu", "rem", "remu",
    "lb", "lbu", "lh", "lhu",
    "sb", "sh",
    "bltu", "bgeu",
    "ecall", "ebreak",
    "fence", "fence.i",
    "csrrw", "csrrs", "csrrc", "csrrwi", "csrrsi", "csrrci",
    "c.addi", "c.mv", "c.jr",       # comprimidas (cualquier "c.")
}

# ---------------------------------------------------------------------------
# Herramientas
# ---------------------------------------------------------------------------
def find_toolchain():
    """Detecta el prefijo del toolchain RISC-V disponible."""
    for prefix in ("riscv32-unknown-elf-", "riscv64-unknown-elf-", "riscv-none-elf-"):
        try:
            subprocess.run([f"{prefix}as", "--version"],
                           capture_output=True, check=True)
            print(f"[build] toolchain: {prefix}")
            return prefix
        except (FileNotFoundError, subprocess.CalledProcessError):
            pass
    sys.exit("[ERROR] No se encontró un toolchain RISC-V. "
             "Instale riscv64-unknown-elf o riscv32-unknown-elf.")


def run(cmd, **kwargs):
    """Ejecuta un comando y aborta si falla."""
    print(f"[run] {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True, **kwargs)
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr, file=sys.stderr)
        sys.exit(f"[ERROR] El comando falló con código {result.returncode}")
    return result


# ---------------------------------------------------------------------------
# Etapa 1: ensamblar
# ---------------------------------------------------------------------------
def assemble(prefix, src, obj):
    run([
        f"{prefix}as",
        "-march=rv32i",
        "-mabi=ilp32",
        "-mno-relax",           # desactiva relaxation (evita instrucciones inesperadas)
        "-o", obj,
        src,
    ])


# ---------------------------------------------------------------------------
# Etapa 2: enlazar
# ---------------------------------------------------------------------------
LINKER_SCRIPT = """\
ENTRY(_start)
SECTIONS {
    . = 0x00000000;
    .text : { *(.text) *(.text.*) }
    /DISCARD/ : { *(.data) *(.bss) *(.rodata) *(.comment) }
}
"""

def link(prefix, obj, elf, ld_script):
    run([
        f"{prefix}ld",
        "-T", ld_script,
        "-m", "elf32lriscv",    # ELF de 32 bits little-endian
        "-o", elf,
        obj,
    ])


# ---------------------------------------------------------------------------
# Etapa 3: extraer binario plano
# ---------------------------------------------------------------------------
def to_binary(prefix, elf, binfile):
    run([
        f"{prefix}objcopy",
        "-O", "binary",
        "--only-section=.text",
        elf,
        binfile,
    ])


# ---------------------------------------------------------------------------
# Etapa 4: disassembly y verificación de instrucciones prohibidas
# ---------------------------------------------------------------------------
def disassemble(prefix, elf, dumpfile):
    result = run([
        f"{prefix}objdump",
        "-d",
        "--no-show-raw-insn",
        elf,
    ])
    with open(dumpfile, "w") as f:
        f.write(result.stdout)
    return result.stdout


def check_forbidden(dump_text):
    """Analiza el disassembly y falla si aparece alguna instrucción prohibida."""
    errors = []
    for lineno, line in enumerate(dump_text.splitlines(), 1):
        # Las líneas de instrucción tienen el formato:
        #   <addr>:    <hexbytes>    <mnemonic>  <operands>
        # o (con --no-show-raw-insn):
        #   <addr>:    <mnemonic>  <operands>
        parts = line.split()
        if not parts:
            continue
        # El primer campo con ':' al final es la dirección
        if len(parts) >= 2 and parts[0].endswith(":"):
            mnemonic = parts[1].lower()
            # Revisar instrucciones comprimidas (cualquier prefijo "c.")
            if mnemonic.startswith("c."):
                errors.append(f"  línea {lineno}: instrucción comprimida '{mnemonic}'")
                continue
            if mnemonic in FORBIDDEN_MNEMONICS:
                errors.append(f"  línea {lineno}: instrucción prohibida '{mnemonic}'")

    if errors:
        print("\n[ERROR] Se encontraron instrucciones prohibidas en el disassembly:")
        for e in errors:
            print(e)
        sys.exit(1)
    print("[OK] No se encontraron instrucciones prohibidas.")


# ---------------------------------------------------------------------------
# Etapa 5: generar rom.hex
# ---------------------------------------------------------------------------
def bin_to_hex(binfile, hexfile):
    with open(binfile, "rb") as f:
        raw = f.read()

    if len(raw) % 4 != 0:
        # Rellenar a múltiplo de 4 bytes
        raw += b"\x00" * (4 - len(raw) % 4)

    words = [struct.unpack_from("<I", raw, i)[0] for i in range(0, len(raw), 4)]
    word_count = len(words)

    if word_count > ROM_WORDS:
        sys.exit(f"[ERROR] El programa ocupa {word_count} palabras "
                 f"({word_count*4} bytes) y supera la ROM de {ROM_WORDS} palabras "
                 f"({ROM_WORDS*4} bytes = 8 KB).")

    print(f"[info] Programa: {word_count} palabras de 32 bits "
          f"({word_count*4} bytes), {ROM_WORDS - word_count} palabras libres.")

    # Rellenar hasta 2048 palabras con NOP
    words += [NOP_WORD] * (ROM_WORDS - word_count)

    with open(hexfile, "w") as f:
        for w in words:
            f.write(f"{w:08x}\n")

    print(f"[OK] {hexfile} generado ({ROM_WORDS} palabras).")
    return word_count


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    src = sys.argv[1]
    if not os.path.isfile(src):
        sys.exit(f"[ERROR] No se encontró el archivo fuente: {src}")

    base = os.path.splitext(src)[0]
    src_dir = os.path.dirname(os.path.abspath(src))

    obj      = base + ".o"
    elf      = base + ".elf"
    binfile  = base + ".bin"
    dumpfile = base + ".dump"
    hexfile  = os.path.join(src_dir, "rom.hex")

    # Script de enlazado temporal
    ld_script = base + "_link.ld"
    with open(ld_script, "w") as f:
        f.write(LINKER_SCRIPT)

    prefix = find_toolchain()

    print(f"\n=== Ensamblando {src} ===")
    assemble(prefix, src, obj)

    print(f"\n=== Enlazando ===")
    link(prefix, obj, elf, ld_script)

    print(f"\n=== Extrayendo binario ===")
    to_binary(prefix, elf, binfile)

    print(f"\n=== Disassembly ===")
    dump = disassemble(prefix, elf, dumpfile)

    print(f"\n=== Verificando instrucciones ===")
    check_forbidden(dump)

    print(f"\n=== Generando rom.hex ===")
    words_used = bin_to_hex(binfile, hexfile)

    # Limpieza de archivos intermedios
    for tmp in [obj, binfile, ld_script]:
        if os.path.exists(tmp):
            os.remove(tmp)

    print(f"""
=== BUILD EXITOSO ===
  Fuente:      {src}
  ELF:         {elf}
  Disassembly: {dumpfile}
  ROM hex:     {hexfile}
  Palabras:    {words_used} / {ROM_WORDS} ({words_used*100//ROM_WORDS}% del espacio)

Copie rom.hex a la carpeta del proyecto Quartus y recompile.
""")


if __name__ == "__main__":
    main()
