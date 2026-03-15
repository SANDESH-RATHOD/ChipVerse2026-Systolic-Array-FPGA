# 🏆 ChipVerse 2026 — Digital VLSI Domain Winner

## INT8 8×8 Systolic Array AI Accelerator on Basys 3 FPGA

> **Won Digital VLSI domain at ChipVerse 2026 — ₹10,000 Prize**

Built a fully working INT8 Systolic Array AI Accelerator on the **Basys 3 FPGA (Xilinx Artix-7 XC7A35T)** — the same architecture that powers **Google's TPU v1** — from scratch in one hackathon.

---

## Demo

```
PC sends:    [a0, a1, a2, a3, w0, w1, w2, w3]  (8 bytes)
FPGA computes in 150 ns
FPGA returns: 16 results via UART (48 bytes)

Example output for a=[1,2,3,4] w=[1,2,3,4]:
  |  10   18   24   28 |
  |  18   36   48   56 |
  |  24   48   72   84 |
  |  28   56   84  112 |
  16/16 PASSED
```

---

## Architecture

```
Switches/UART → Input Regs → 4×4 Systolic Array → ReLU Unit → Result Regs → UART TX / 7-seg
                                     ↑
                              16 PEs in parallel
                         each PE: acc += a × w per cycle
```

### Processing Element (pe.v)
- 8-bit signed inputs × 8-bit signed weights
- 19-bit accumulator — overflow-safe (127×127×11 = 177,419 < 262,143)
- **2-stage pipeline** — multiply stage → accumulate stage
- Mapped to **DSP48E1** hardware block (zero LUT cost)
- Operand isolation — inputs held at 0 when idle → **-30% multiplier power**

### 4×4 Systolic Array (systolic_array_4x4.v)
- 16 PEs arranged in a 4×4 mesh
- Data flows right, weights flow down
- All 16 MACs happen every clock cycle
- Formula: `out[r][c] = (11 - max(r,c)) × a[r] × w[c]`

### ReLU Activation Unit (relu_unit.v)
- Applied after every matrix multiply — exactly like a real TPU
- SW[1:0] selects mode:

| SW[1:0] | Mode    | Effect                    |
|---------|---------|---------------------------|
| 00      | Bypass  | Raw accumulator value      |
| 01      | ReLU    | max(0, x)                 |
| 10      | ReLU6   | min(max(0,x), 6)          |
| 11      | Sign    | x≥0 → 1,  x<0 → 0        |

### FSM Controller (inside top_4x4.v)
7-state **Gray code** encoded FSM — only 1 bit toggles per transition → -20% switching power

```
S_IDLE → S_ARST → S_COMPUTE → S_LATCH → S_RELU → S_TX → S_IDLE
```

---

## PPA Results

| Metric | Before PPA | After PPA | Improvement |
|--------|-----------|-----------|-------------|
| Clock | 100 MHz | **150 MHz** | +50% |
| MACs/sec | 160 M | **240 M** | +50% |
| DSP48 | 16 / 90 | 16 / 90 | 17.8% |
| LUTs | ~700 | ~720 | 3.4% |
| Flip-Flops | ~780 | ~1,292 | +512 (pipeline) |
| Dynamic power | baseline | **-15 to 20%** | gray code + isolation |

### PPA Optimisations Applied
1. **Pipelined PE** — breaks critical path, enables 150 MHz
2. **Operand isolation** — DSP48 inputs = 0 when idle, -30% multiplier power
3. **Gray code FSM** — 1 bit change per transition, -20% FSM switching power
4. **6-bit counter** — was 8-bit (max needed: 47), saves 2 FFs
5. **1-cycle S_ARST** — async reset only needs 1 cycle (was 2)

---

## Bugs Found and Fixed (11 Critical)

| # | File | Bug | Effect |
|---|------|-----|--------|
| 1 | pe.v | ACC_WIDTH=17 | Silent overflow for inputs >80 |
| 2 | systolic_array_4x4.v | en tied 1'b1 | FSM enable had zero effect |
| 3 | top_4x4.v | Skew buffer present | 9/16 wrong results on board |
| 4 | top_4x4.v | TX sent result[17] always 0 | All negatives decoded wrong |
| 5 | top_4x4.v | sa_rst in S_LATCH | All zeros captured |
| 6 | top_4x4.v | Wire widths [16:0] | Sign bit always 0 |
| 7 | top_4x4.v | Comma inside comment | Syntax error in Vivado |
| 8 | mfu.v | B[r][run] not B[run][c] | Computed A×Bᵀ not A×B |
| 9 | top_8x8.v | bufA/bufB only 16 entries | 48 of 64 results lost |
| 10 | top_8x8.v | relu_en + result_we same cycle | Stale data captured |
| 11 | pe.v | generate if/else | FF count doubled to 1617 |

---

## File Structure

```
ChipVerse2026-Systolic-Array-FPGA/
├── rtl/
│   ├── pe.v                  Processing Element — pipelined MAC unit
│   ├── systolic_array_4x4.v  4×4 array of 16 PEs
│   ├── systolic_array_8x8.v  8×8 array of 64 PEs
│   ├── top_4x4.v             Top module — FSM, UART, ReLU, 7-seg
│   ├── top_8x8.v             8×8 top — adds SPI, BRAM, ping-pong
│   ├── relu_unit.v           ReLU/ReLU6/sign activation
│   ├── uart_rx.v             115200 baud UART receiver
│   ├── uart_tx.v             115200 baud UART transmitter
│   ├── seven_seg_driver.v    Double-Dabble BCD display driver
│   ├── skew_buffer.v         Input skew buffer (8×8 only)
│   ├── weight_bram.v         Block RAM weight storage
│   ├── spi_slave.v           SPI Mode 0 slave interface
│   └── mfu.v                 Matrix Feed Unit (C = A×B)
├── tb/
│   ├── tb_4x4.v              4×4 testbench — 16 checks
│   ├── tb_8x8.v              8×8 testbench — 64 checks
│   ├── tb_pe.v               PE unit testbench
│   └── tb_interactive.v      Custom input testbench
├── scripts/
│   └── uart_host.py          Python PC tester (pyserial)
├── basys3.xdc                Pin constraints for Basys 3
└── README.md
```

---

## How to Simulate

```bash
# Install iverilog (OSS-CAD-Suite)

# Simulate 4×4
iverilog -g2012 -o sim_4x4 tb/tb_4x4.v rtl/systolic_array_4x4.v rtl/pe.v
vvp sim_4x4
# Expected: 16/16 PASSED

# View waveform
gtkwave wave.vcd
```

---

## How to Run on Basys 3

**In Vivado — add these sources:**
```
rtl/pe.v
rtl/systolic_array_4x4.v
rtl/relu_unit.v
rtl/uart_rx.v
rtl/uart_tx.v
rtl/seven_seg_driver.v
rtl/top_4x4.v        ← set as Top
basys3.xdc
```

**On the board:**
```
1. Press BTNC           → reset
2. Set SW[15:0]         → a values (4-bit each)
3. Press BTND           → latch A
4. Set SW[15:0]         → w values
5. Set SW[1:0]          → ReLU mode
6. Press BTNU           → compute
7. LED[15] ON           → DONE
8. 7-seg shows result   → press BTNR to browse all 16
```

**UART test from PC:**
```bash
pip install pyserial
python scripts/uart_host.py --port COM6 --a 1 2 3 4 --w 1 2 3 4
# Expected: 16/16 PASSED
```

---

## Button & LED Map

| Button | Action |
|--------|--------|
| BTNC | Reset |
| BTND | Latch A values |
| BTNU | Latch W + Compute |
| BTNR | Next PE on 7-seg |
| BTNL | Prev PE on 7-seg |

| LED | Meaning |
|-----|---------|
| LED[15] | DONE |
| LED[14] | COMPUTING |
| LED[13] | UART RX active |
| LED[11:8] | PE index on 7-seg |
| LED[1:0] | ReLU mode |

---

## Target Hardware

| Item | Value |
|------|-------|
| Board | Digilent Basys 3 |
| FPGA | Xilinx Artix-7 XC7A35T |
| Package | CPG236 |
| Clock | 100 MHz onboard (PPA target 150 MHz) |
| DSP48E1 | 90 total, 16 used (17.8%) |
| Max array | 9×9 = 81 PEs (DSP48 limit) |

---

## Real World Context

Google's TPU v1 (2016) uses the same systolic array architecture:
- **256×256** array vs our **4×4**
- Same weight-stationary dataflow
- Same ReLU after each layer
- Same INT8 quantisation

We implemented the same fundamental concept on a ₹8,000 dev board in one hackathon.

---

## Team

| Name | Role |
|------|------|
| **Sandesh** | Team Lead — RTL design, FPGA implementation, synthesis |
| **Sai Pavan Kumar** | Verification Engineer — testbench, simulation, bug fixing |
| **Charitha** | FSM design, gray code optimisation, presentation |
| **Preksha** | FSM design, state machine analysis, presentation |

---

## Tech Stack

`Verilog` · `Vivado 2020+` · `Basys 3` · `Artix-7` · `DSP48E1` · `iverilog` · `GTKWave` · `Python`

---

*ChipVerse 2026 — Digital VLSI Domain — 🏆 First Place — ₹10,000*
