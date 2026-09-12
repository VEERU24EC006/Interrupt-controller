# Interrupt-controller

CLIC - Core-Local Interrupt Controller

A RISC-V CLIC (Core-Local Interrupt Controller) implementation in SystemVerilog,
designed for integration with the srv32 RISC-V processor core. Targets the
Digilent Basys 3 (Artix-7 xc7a35tcpg236-1) FPGA board.


Features

- 64 interrupt sources with independent configuration
- Level + priority-based arbitration (4-bit level, 4-bit priority per source)
- Level-based preemption (interrupts only fire when level exceeds CPU current level)
- Selective Hardware Vectoring (SHV) per-source opt-in for direct vector table lookup
- Edge-triggered and level-sensitive interrupt modes (via clic_gateway synchronizer)
- AXI4-Lite slave interface for CPU bus access
- Memory-mapped register file at base address 0x0200_0000
- Machine Trap Vector Table (MTVT) with configurable base address

```text
Architecture

                      +-------------------------------------------+
                      |              clic_top.sv                  |
                      |     (AXI4-Lite Slave + Pin Mapping)       |
                      |                                           |
   AXI4-Lite Bus ---->|  +---------------------------------+      |---> cpu_int_req
   (from CPU)         |  |         clic_bus.sv             |      |---> cpu_int_id[5:0]
                      |  |  (Register File + SHV Logic)    |      |---> cpu_vector_addr[31:0]
  ext_irq_pins ------>|  |  +---------------------------+  |      |
   [1:0]              |  |  |      clic_core.sv         |         | 
                      |  |  |   (Priority Arbiter)      |  |      |
                      |  |  +---------------------------+  |      |
                      |  +---------------------------------+      |
                      +-------------------------------------------+

```
  clic_gateway.sv -- Per-source synchronizer + edge/level latch (standalone module)


Module Hierarchy

clic_top       - Module used for simulation. Connects all 64 interrupt sources
                 directly for full testbench verification. Includes AXI4-Lite
                 interface and exposes the full 64-bit ext_irq vector for
                 testbench stimulus.

soc_top        - Module used for synthesis and bitstream generation on the
                 Basys 3 board. Maps only 2 physical pins (switches) to
                 interrupt sources, keeping pin count minimal for hardware
                 deployment. Outputs cpu_int_req and cpu_int_id to LEDs.


clic_bus       - Register file with memory-mapped I/O. Captures external interrupts
                 into pending bits, decodes bus addresses, computes SHV vector address.
                 Instantiates clic_core.

clic_core      - Combinational priority arbiter. Filters active interrupts (ip & ie),
                 selects winner by {level, priority}, applies preemption gate
                 (level > CPU current level).

clic_gateway   - 3-stage synchronizer for metastability protection. Generates pending
                 bits for edge-triggered and level-sensitive modes.

clic_define    - SystemVerilog package with global parameters (64 sources,
                 base address, register offsets).

```text
Register Map

Each interrupt source has a 4-byte configuration block:

  Offset         Register       Bits                  Description
  ----------     ----------     --------------------  ----------------------------
  0x000-0x03F    clicint_ip     [0]                   Interrupt pending bit
  0x100-0x13F    clicint_ie     [0]                   Interrupt enable bit
  0x200-0x23F    clicint_ctl    [7:4] level           Level and priority control
                                [3:0] priority
  0x300-0x33F    clicint_attr   [1] SHV               Attribute control
                                [0] edge/level
  0x400          mtvt_base_addr [31:0]                Machine Trap Vector Table
                                                      base address

```

Simulation

4 test cases verified in Xilinx Vivado behavioral simulation. All tests PASS.

Test 1: Level Arbitration
Source 5 (Level 3) vs Source 10 (Level 2). Higher level wins.
Result: cpu_int_id = 5. PASS.

Test 2: Priority Arbitration
Source 15 (Level 2, Priority 1) vs Source 20 (Level 2, Priority 3).
Higher priority wins at same level. Result: cpu_int_id = 20. PASS.

Test 3: Tie-Breaker
Source 25 (Level 3, Priority 3) vs Source 30 (Level 3, Priority 3).
Lower source ID wins the tie. Result: cpu_int_id = 25. PASS.

Test 4: Selective Hardware Vectoring (SHV)
SHV enabled for Source 25. Vector address = mtvt_base (0x1000) + (25 * 4) = 0x1064.
Result: cpu_vector_addr = 0x00001064. PASS.

```text 
FPGA Implementation

Target: Digilent Basys 3 (Artix-7 xc7a35tcpg236-1)

Resource Utilization:
  Resource         Used     Available    Utilization
  ----------       ----     ---------    -----------
  Slice LUTs       918      20,800       4.41%
  Flip-Flops       1,152    41,600       2.77%
  I/O Pins         9        106          8.49%
```

```text
Power Analysis:
  Total On-Chip Power    0.079 W
  Clocks                 0.056 W (70%)
  I/O                    0.013 W (16%)
  Logic                  0.002 W (3%)
  Signals                0.002 W (3%)
  Junction Temperature   23.4 C
  Thermal Margin         59.6 C (11.9 W)

Timing Summary:
  Worst Setup Slack      8.496 ns
  Worst Hold Slack       0.126 ns
  Worst Pulse Width Slack 4.500 ns
  All constraints met    Yes
```

```text
Pin Mapping (Basys 3)

  Signal             Board Pin    Function
  -----------------  ---------    --------
  clk                W5           100 MHz system clock
  reset_n            U18          Center push button (active low)
  ext_irq_pins[0]    V17          Switch 0 -> Source 0 (GPIO)
  ext_irq_pins[1]    V16          Switch 1 -> Source 1 (UART)
  cpu_int_req        L1           LED 15 (interrupt active)
  cpu_int_id[0]      U16          LED 0 (ID bit 0)
  cpu_int_id[1]      E19          LED 1 (ID bit 1)
  cpu_int_id[2]      U19          LED 2 (ID bit 2)
  cpu_int_id[3]      V19          LED 3 (ID bit 3)

```

```text
Project Structure

Interrupt-controller/
  RTL/
    clic_define.sv      - Global parameters package
    clic_core.sv         - Priority arbiter
    clic_bus.sv          - Register file + bus interface
    clic_gateway.sv      - Synchronizer + edge/level latch
    clic_top.sv          - AXI4-Lite top-level wrapper
    clic_tb.sv           - Testbench (4 test cases)
    soc_top.sv           - XDC constraints (Basys 3)
  Simulation/
    sim1.png             - Test 1 waveform
    sim2.png             - Test 2 waveform
    sim3.png             - Test 3 waveform
    sim4.png             - Test 4 waveform
    testcase1.png        - Test 1 code snippet
    testcase2.png        - Test 2 code snippet
    testcase3.png        - Test 3 code snippet
    testcase4.png        - Test 4 code snippet
  Synthesis&implementation/
    Schematic.png        - Implemented design schematic
    schematic2.png       - Synthesized design schematic
    ResourceUtilization.png
    PowerAnalysis.png
    DesignTimingSummary.png
    soc_top.bit          - FPGA bitstream
  LICENSE                - MIT License
  README.md

``` 
How to Use

Simulation (Vivado):
1. Create a new Vivado project targeting xc7a35tcpg236-1
2. Add all RTL/*.sv files as design sources
3. Add clic_tb.sv as a simulation source
4. Run behavioral simulation - all 4 tests should display PASS

FPGA Programming:
1. Generate bitstream from the included soc_top.bit, or re-run implementation
2. Program the Basys 3 board via USB
3. Use switches 0-1 to trigger interrupt sources
4. Observe LED 15 (interrupt active) and LEDs 0-3 (winning source ID)


License

MIT License - Copyright (c) 2026 Veer
