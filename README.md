[![CI](https://github.com/deuskane/asylum-component-stack/actions/workflows/ci.yml/badge.svg)](https://github.com/deuskane/asylum-component-stack/actions/workflows/ci.yml)

**Table of Contents**
- **Introduction**: short overview of this repository
- **HDL Modules**: detailed description of modules in `hdl/`
- **Regmap (CSR)**: register map files in `hdl/csr/` (if present)
- **Verification**: simulation and testbench information from `sim/` and `stack.core`
- **References**: important files and how to run simulations

**Introduction**

This repository contains a small VHDL component named `stack` (a push/pop stack) and its supporting package and testbench. The project is packaged for use with FuseSoC via the `stack.core` core file. It is intended as a reusable component for hardware designs that need a small synchronous stack implemented over a simple RAM primitive.

**HDL Modules**

This section documents the VHDL modules found in the `hdl/` folder. Each module includes a table of generics and a table of ports, followed by a short functional description.

- Module: `stack` (`hdl/stack.vhd`)

	Generics

	| Name | Type | Default | Description |
	|------|------|---------|-------------|
	| `WIDTH` | natural | `32` | Data width of each stack word (bits)
	| `DEPTH` | natural | `4` | Depth (number of words) of the stack
	| `OVERWRITE` | natural | `0` | When non-zero, allow writes when full (overwrite behavior)

	Ports

	| Name | Direction | Type | Description |
	|------|-----------|------|-------------|
	| `clk_i` | in | `std_logic` | Clock input (rising-edge synchronous)
	| `cke_i` | in | `std_logic` | Clock enable; operations occur when asserted
	| `arstn_i` | in | `std_logic` | Asynchronous active-low reset (clears stack)
	| `push_val_i` | in | `std_logic` | Push request input (valid signal)
	| `push_ack_o` | out | `std_logic` | Push ready/acknowledge output (indicates push accepted)
	| `push_data_i` | in | `std_logic_vector(WIDTH-1 downto 0)` | Data to push onto the stack
	| `pop_val_o` | out | `std_logic` | Pop data valid output (indicates data available)
	| `pop_ack_i` | in | `std_logic` | Pop acknowledge / consume input (assert to take data)
	| `pop_data_o` | out | `std_logic_vector(WIDTH-1 downto 0)` | Data output from pop operation

	Functional description

	The `stack` module implements a small LIFO stack using an underlying single-port or 1r1w RAM primitive (`ram_1r1w`). The main features are:

	- Synchronous operation on the rising edge of `clk_i` when `cke_i` is `'1'`.
	- Asynchronous active-low reset `arstn_i` clears the stack pointer and element count.
	- A `push` operation occurs when `push_val_i` is asserted and `push_ack_o` indicates acceptance. The module controls `push_ack_o` depending on the `OVERWRITE` generic and the fullness of the stack:
		- If `OVERWRITE = 0`, `push_ack_o` is `'1'` only when the stack is not full (prevents overwrite).
		- If `OVERWRITE /= 0`, `push_ack_o` is always `'1'` (writes can overwrite when full).
	- A `pop` is indicated by `pop_val_o` when stack is not empty. The consumer must assert `pop_ack_i` to actually read/consume the top element; `pop_data_o` provides the data.
	- Internally the component keeps `nb_elt_r` (number of elements) and `ptr_last_r` (pointer to last element) and uses `ram_1r1w` to store words.

	See `hdl/stack.vhd` and `hdl/stack_pkg.vhd` for the full implementation and component declaration.


**Verification**

This repository includes a testbench in `sim/tb_stack.vhd` and a FuseSoC core description in `stack.core` which exposes a simulation target.

- Testbench: `sim/tb_stack.vhd`
	- The testbench instantiates `stack` with generics: `WIDTH = 8`, `DEPTH = 4`, `OVERWRITE = 0`.
	- It performs the following checks: reset behavior, push sequence until full, pop sequence verifying data and flags, and push/pop mixed scenarios. Assertions are used to flag unexpected behavior.

- FuseSoC core: `stack.core`
	- The core file declares filesets `files_hdl` and `files_sim` and a `sim_basic` target that runs `tb_stack` with `ghdl` and exports `--vcd=dut.vcd` via `run_options`.
	- The core also documents parameters that map to VHDL generics: `WIDTH`, `DEPTH`, `OVERWRITE` (see `stack.core` for defaults and descriptions).
