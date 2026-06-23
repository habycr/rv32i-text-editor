# Testbenches de validación del stall de `lw`

Estos dos testbenches NO forman parte del proyecto a entregar (no van en el
`.qsf` de síntesis); son evidencia de verificación de que el parche del
stall de `lw` funciona correctamente, generados y corridos con Icarus
Verilog (`iverilog`/`vvp`) durante el desarrollo del parche.

## Cómo correrlos

Requieren `iverilog` (Icarus Verilog, soporta SystemVerilog-2012 con
limitaciones — ver advertencias de compilación, no afectan el resultado).

```bash
cd tb/sim_validacion_stall

# Caso 1: lw ra,0(sp) seguido de jalr (ret) — el caso de falla original
iverilog -g2012 -o sim1.out \
  ../../cpu/riscv_cpu.sv ../../cpu/riscv_datapath.sv ../../cpu/program_counter.sv \
  ../../cpu/control_unit.sv ../../cpu/register_file.sv ../../cpu/alu.sv \
  ../../cpu/sign_extend.sv ../../rtl/peripherals/ram/ram.sv \
  ../../rtl/peripherals/rom/rom.sv tb_lw_stall.sv
# El testbench espera el archivo rom_init.hex con el nombre exacto usado
# en el parámetro INIT_FILE del testbench; renombre o copie
# caso1_lw_jalr.hex -> rom_init.hex antes de correr, o edite el
# parámetro INIT_FILE dentro de tb_lw_stall.sv.
cp caso1_lw_jalr.hex rom_init.hex
vvp sim1.out

# Caso 2: lw consecutivos + branch inmediatamente después de un lw
iverilog -g2012 -o sim2.out \
  ../../cpu/riscv_cpu.sv ../../cpu/riscv_datapath.sv ../../cpu/program_counter.sv \
  ../../cpu/control_unit.sv ../../cpu/register_file.sv ../../cpu/alu.sv \
  ../../cpu/sign_extend.sv ../../rtl/peripherals/ram/ram.sv \
  ../../rtl/peripherals/rom/rom.sv tb_lw_stall2.sv
cp caso2_lw_consecutivos_branch.hex rom_init2.hex
vvp sim2.out
```

## Qué verifica cada testbench

### `tb_lw_stall.sv` (caso 1 — el bug original reportado)

Programa ensamblado a mano:

```
addi sp, x0, 16
addi t0, x0, 64        # 64 = dirección de "retorno" de prueba, alineada a 4
sw   t0, 0(sp)
addi t1, x0, 0x111      # instrucción de relleno
lw   ra, 0(sp)          # <-- debe tardar 2 ciclos (1 de stall)
addi t2, x0, 0x222      # instrucción inmediatamente después del lw
jalr x0, ra, 0           # ret: salta a la dirección que dejó el lw en ra
...
[en la dirección 0x40]:
addi t3, x0, 0x3ab       # marcador: si esto se ejecuta, el ret saltó bien
```

Verifica:
- `ra` contiene el valor leído de RAM por `lw` (`0x40`), no un valor basura.
- El `jalr` salta a la dirección correcta — confirma que el `ret` tras un
  `lw` (el patrón que reportó la falla original) ya no se rompe.

**Resultado obtenido:** `OK` en ambas verificaciones.

### `tb_lw_stall2.sv` (caso 2 — casos límite del stall)

Verifica, en un solo programa:
- Dos `lw` consecutivos (sin ninguna instrucción entre ellos): cada uno
  tarda 2 ciclos, sin interferencia entre sí.
- Un `beq` NO tomado inmediatamente después de un `lw`: la instrucción
  siguiente al branch se ejecuta con normalidad.
- Un `lw` inmediatamente después de una instrucción ALU normal.
- Un `beq` SÍ tomado inmediatamente después de un `lw`: el salto ocurre
  correctamente y la instrucción que NO debía ejecutarse (justo después del
  branch tomado) en efecto no se ejecuta.
- `sw` permanece de 1 ciclo (no entra al stall).

**Resultado obtenido:** todos los registros verificados coinciden con el
valor esperado (`>>> TODO CORRECTO <<<`).

## Limitaciones de esta verificación

- Esto es una simulación de **comportamiento RTL** (Icarus Verilog), NO
  una simulación post-síntesis ni una prueba en hardware real. Sigue
  siendo necesario:
  1. Simular en ModelSim/QuestaSim (la herramienta del curso) para
     confirmar que el comportamiento es idéntico — Icarus tiene soporte
     parcial de SystemVerilog (ver advertencias `sorry:` al compilar,
     relacionadas con `unique case` y "constant selects en always_*";
     no afectan la lógica funcional en este diseño, pero ModelSim es la
     herramienta de referencia del proyecto).
  2. Compilar en Quartus Prime 18.0 y revisar que la RAM siga
     infiriéndose como M10K con el nuevo puerto de lectura posedge (ver
     checklist de aceptación en `PATCH_NOTES.md`).
  3. Probar en hardware real (DE1-SoC) con el firmware completo del
     editor de texto, no solo con este programa de prueba aislado de
     7-12 instrucciones.
- El testbench conecta `ram` directamente a la CPU sin pasar por
  `address_translator` (se fuerza `cs_ram_o = 1` todo el tiempo) para
  aislar específicamente el comportamiento del stall de memoria. El
  `address_translator` real es puramente combinacional y no introduce
  ninguna latencia adicional, así que este aislamiento no cambia el
  comportamiento de timing relevante — pero no sustituye una simulación
  del sistema completo.
