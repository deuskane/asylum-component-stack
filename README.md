<!--
  README GENERATION INSTRUCTIONS (for the next regeneration run)
  ----------------------------------------------------------------
  This README follows the common Asylum IP model. Regenerate it from the
  sources, never from the previous README text alone.

  Sources of truth (in priority order):
    1. hdl/*.vhd            : entities, generics, ports, packages
    2. hdl/csr/*.hjson      : register map (regtool); *_csr.md/.h are generated
    3. <IP>.core            : VLNV (name), filesets, targets, depends, revisions
    4. mk/targets.txt       : target list shown by `make help`; mk/defs.mk
    5. sim/, syn/, esw/, boards/ : testbenches, constraints, software
  Section order (keep it, same headings in every IP):
    CI badge / Title + one-line description + VLNV / Table of Contents /
    Introduction (Key Features) / Block Diagram / Top-Level (Parameters,
    Ports, Instantiation Example) / HDL Modules / Register Map /
    Verification / Synthesis / Design Notes (optional) /
    Directory Structure / Dependencies
  Rules:
    - Language: English. Tables: Parameters = Name|Type|Default|Description,
      Ports = Name|Direction|Type|Description (grouped by interface).
    - Register Map: link to the generated hdl/csr/<X>_csr.md (plus the
      .hjson source and _csr.h header); never copy register tables here.
    - Top-Level = sbi_* wrapper if present, else the entity used by the
      `default` target, else the main entity (libraries: list packages).
    - Write "This IP has no software-visible registers." / "No dedicated
      synthesis target ..." instead of removing a section.
    - Keep still-accurate hand-written content (ISA tables, results,
      images) in "Design Notes"; drop anything not backed by the sources.
    - Block diagram: doc/<NAME>.drawio (NAME = 4th field of the VLNV),
      top entity box with generics on top, inputs left, outputs right,
      bus interfaces as bold arrows, internal blocks colour-coded
      (CSR yellow, FIFO/memory green, core logic blue, external grey).
      Update it whenever ports/generics/sub-blocks change.
    - Do not edit generated files (hdl/csr/*_csr.*) or the CI badge URL.
-->
[![CI](https://github.com/deuskane/asylum-component-stack/actions/workflows/ci.yml/badge.svg)](https://github.com/deuskane/asylum-component-stack/actions/workflows/ci.yml)

# asylum-component-stack

**LIFO stack with valid / acknowledge push and pop interfaces, built on an asynchronous-read `ram_1r1w`, with optional overwrite when full.**

VLNV: `asylum:component:stack:1.0.2`

## Table of Contents

1. [Introduction](#introduction)
2. [Block Diagram](#block-diagram)
3. [Top-Level](#top-level)
4. [HDL Modules](#hdl-modules)
5. [Register Map](#register-map)
6. [Verification](#verification)
7. [Synthesis](#synthesis)
8. [Design Notes](#design-notes)
9. [Directory Structure](#directory-structure)
10. [Dependencies](#dependencies)

## Introduction

This IP is a small hardware stack (last in, first out), typically used as a return-address stack in a processor. Words are stored in a `ram_1r1w` instance (core `asylum:component:ram`) with asynchronous read; a pointer to the next free slot (`ptr_last_r`) and an element counter (`nb_elt_r`) give the top of the stack and the full / empty state. The top word is always visible on `pop_data_o` while the stack is not empty. With `OVERWRITE /= 0` a push on a full stack is accepted and overwrites the oldest word (circular behaviour).

### Key Features

- Generic word width (`WIDTH`) and depth (`DEPTH`, power of 2)
- Push interface `push_val_i` / `push_ack_o` / `push_data_i`, `push_ack_o = not full` (or always `1` with `OVERWRITE /= 0`)
- Pop interface `pop_val_o` / `pop_ack_i` / `pop_data_o`, `pop_val_o = not empty`, top word presented combinationally
- Simultaneous push and pop replace the top word in one cycle
- Clock enable `cke_i` freezes the stack (pointers and RAM write)
- Active-low reset `arstn_i`, sampled on the rising edge of `clk_i`
- Component declaration available in `asylum.stack_pkg`

## Block Diagram

Diagram: [doc/stack.drawio](doc/stack.drawio) (open with diagrams.net or the VS Code Draw.io extension).

- The flag / handshake logic derives `full` (MSB of `nb_elt_r`) and `empty` (`nb_elt_r = 0`), drives `push_ack_o` and `pop_val_o` and computes the `push` and `pop` events.
- The `transition` process updates `nb_elt_r` (`log2(DEPTH)+1` bits) and `ptr_last_r` (`log2(DEPTH)` bits) on push only (+1) or pop only (-1); push and pop together leave them unchanged.
- The RAM read address is always `ptr_last_r-1` (top of stack); the write address is `ptr_last_r` for a push, or `ptr_last_r-1` when a pop happens in the same cycle.
- `ins_ram_1r1w` (`SYNC_READ = false`) is written with `push_data_i` on every push and its read data is `pop_data_o`.

## Top-Level

Top-level entity: **`stack`** ([hdl/stack.vhd](hdl/stack.vhd)), library `asylum`, component declared in `asylum.stack_pkg`.

### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `WIDTH` | natural | `32` | Word width in bits |
| `DEPTH` | natural | `4` | Number of words; must be a power of 2 (`full` is the MSB of a `log2(DEPTH)+1`-bit counter) |
| `OVERWRITE` | natural | `0` | `0`: push refused when full; `/= 0`: push always accepted, the oldest word is overwritten when full |

### Ports

#### Clock & Reset

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `clk_i` | in | std_logic | Clock |
| `cke_i` | in | std_logic | Clock enable, active high (pointer update and RAM write) |
| `arstn_i` | in | std_logic | Reset, active low, synchronous to `clk_i` (despite its name): clears `nb_elt_r` and `ptr_last_r` |

#### Push

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `push_val_i` | in | std_logic | Push request |
| `push_ack_o` | out | std_logic | Push accepted (`not full`, or `1` when `OVERWRITE /= 0`) |
| `push_data_i` | in | std_logic_vector(WIDTH-1 downto 0) | Word to push |

#### Pop

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `pop_val_o` | out | std_logic | Stack not empty: `pop_data_o` is valid |
| `pop_ack_i` | in | std_logic | Pop: the top word is removed when `pop_val_o = 1` |
| `pop_data_o` | out | std_logic_vector(WIDTH-1 downto 0) | Top of stack (asynchronous RAM read at `ptr_last_r-1`) |

### Instantiation Example

```vhdl
library asylum;
use     asylum.stack_pkg.all;

  ins_stack : entity asylum.stack
    generic map
    ( WIDTH       => 10
     ,DEPTH       => 16
     ,OVERWRITE   => 1
    )
    port map
    ( clk_i       => clk
     ,cke_i       => cke
     ,arstn_i     => arst_b
     ,push_val_i  => stack_push
     ,push_ack_o  => stack_push_ack
     ,push_data_i => stack_push_data   -- std_logic_vector(9 downto 0)
     ,pop_val_o   => stack_not_empty
     ,pop_ack_i   => stack_pop
     ,pop_data_o  => stack_top          -- std_logic_vector(9 downto 0)
    );
```

## HDL Modules

| File | Unit | Kind | Role |
|------|------|------|------|
| [hdl/stack_pkg.vhd](hdl/stack_pkg.vhd) | `stack_pkg` | package | Component declaration of `stack` |
| [hdl/stack.vhd](hdl/stack.vhd) | `stack` | entity | Top-level: counters, flags, address selection, `ram_1r1w` instance |

There is no secondary entity in this IP; the storage is the `ram_1r1w` entity of `asylum:component:ram`.

## Register Map

This IP has no software-visible registers.

## Verification

### Testbenches

| File | DUT | Description |
|------|-----|-------------|
| [sim/tb_stack.vhd](sim/tb_stack.vhd) | `stack` (generics `WIDTH`, `DEPTH`, `OVERWRITE` of the testbench, defaults 8 / 8 / 0) | Self-checking UVVM testbench. The handshakes and `cke_i` / `arstn_i` are driven cycle by cycle and every cycle `pop_val_o`, `push_ack_o` and `pop_data_o` (top of stack) are compared with a reference model. Tests: 1) flags after reset; 2) push up to full, pop in LIFO order; 3) `DEPTH+3` pushes on a full stack: refused with `OVERWRITE = 0`, accepted with `OVERWRITE /= 0` (the stack keeps the last `DEPTH` words); 4) simultaneous push and pop at every level 0 to `DEPTH` (top word replaced; push only when empty; pop only when full with `OVERWRITE = 0`); 5) `cke_i = 0` freezes the stack (push, pop, push+pop, half full and full); 6) synchronous reset `arstn_i`: no effect before the clock edge, stack empty after it, also with `cke_i = 0` and a push+pop request; 7) 1200 cycles of random push / pop / `cke_i`. `report_alert_counters(FINAL)` gives the verdict (4053 checks with `sim_basic`, 3686 with `sim_overwrite`) |

### Targets

| Target | Toplevel | Description |
|--------|----------|-------------|
| `default` | `stack` | HDL fileset only (not a simulation) |
| `sim_basic` | `tb_stack` | Simulation of all cases, `WIDTH=8`, `DEPTH=8`, `OVERWRITE=0` (GHDL, UVVM) |
| `sim_overwrite` | `tb_stack` | Simulation of all cases, `WIDTH=16`, `DEPTH=4`, `OVERWRITE=1` (GHDL, UVVM) |

The `.core` parameters `WIDTH` (int, 8), `DEPTH` (int, 8) and `OVERWRITE` (int, 0) are the testbench generics set by the `sim_*` targets.

### How to Run

The default tool is GHDL (`mk/defs.mk`: `TOOL ?= ghdl`, `TARGET ?= sim_basic`).

```bash
make help                 # variables, rules and target list (mk/targets.txt)
make sim_basic            # run one target (log in log/)
make nonreg_sim           # run every sim_* target
make clean                # remove build/
```

Equivalent FuseSoC command:

```bash
fusesoc --cores-root . run --build-root build --target sim_basic asylum:component:stack:1.0.2
```

### Simulation Features

- Both `sim_*` targets analyze with `-Wall -fsynopsys -frelaxed --no-vital-checks` and run with `--fst=dut.fst --ieee-asserts=disable` (waveform always written to `dut.fst`).
- The testbench requires a power-of-2 `DEPTH` (the pointer `ptr_last_r` wraps modulo `2**log2(DEPTH)`).

## Synthesis

No dedicated synthesis target. The HDL of the `default` target is synthesizable: `stack.vhd` contains no simulation-only construct (no `textio`, file access, `report` or `wait`); the `ram_1r1w` it instantiates only has a `translate_off` check that `DEPTH` is a power of 2. The storage is `WIDTH x DEPTH` bits of RAM with an asynchronous read port (distributed / LUT RAM or registers), plus a `log2(DEPTH)+1`-bit counter and a `log2(DEPTH)`-bit pointer.

## Design Notes

### Operation

| `push` | `pop` | `nb_elt_r` | `ptr_last_r` | RAM write |
|--------|-------|------------|--------------|-----------|
| 0 | 0 | unchanged | unchanged | none |
| 1 | 0 | +1 (unchanged if full) | +1 | `push_data_i` at `ptr_last_r` |
| 0 | 1 | -1 | -1 | none |
| 1 | 1 | unchanged | unchanged | `push_data_i` at `ptr_last_r-1` (top replaced) |

- `push = push_val_i and push_ack_o`, `pop = pop_val_o and pop_ack_i`; all updates require `cke_i = 1`, except the synchronous reset (`arstn_i = 0` on a rising edge clears the stack whatever `cke_i`).
- `pop_data_o` shows the top word before the clock edge that performs the pop; the next word appears after the edge.
- With `OVERWRITE /= 0` and a full stack, a push keeps `nb_elt_r` at `DEPTH` and advances `ptr_last_r`, which wraps on the oldest word: the stack keeps the last `DEPTH` pushed words.

## Directory Structure

```
asylum-component-stack/
├── stack.core              # FuseSoC core (asylum:component:stack)
├── Makefile                # Common Asylum Makefile (FuseSoC wrapper)
├── mk/
│   ├── defs.mk             # FILE_CORE, default TARGET and TOOL
│   └── targets.txt         # Target list (generated from the .core)
├── doc/
│   └── stack.drawio        # Block diagram
├── hdl/
│   ├── stack_pkg.vhd
│   └── stack.vhd
├── sim/
│   └── tb_stack.vhd        # UVVM testbench
└── .github/workflows/ci.yml  # CI (sim_basic, sim_overwrite)
```

## Dependencies

| Core | Used by (fileset) | Purpose |
|------|-------------------|---------|
| `>=asylum:component:ram:1.0.0` | `files_hdl` | `ram_1r1w` storage (`ram_pkg`); also brings `asylum:utils:pkg` (`math_pkg`: `log2`) used by `stack` |
| `bitvis:verification:uvvm` | `files_sim` | UVVM utility library (testbench) |
