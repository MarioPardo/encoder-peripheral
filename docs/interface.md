# Hardware/Software Interface Specification

## 1. Overview
This document specifies the hardware/software interface for a memory-mapped
quadrature encoder peripheral.

The peripheral decodes A/B quadrature encoder signals , maintains a signed
position count, computes velocity over a fixed time window, and exposes this
information via memory-mapped registers.

The design is synchronous, deterministic, and suitable for integration into
a larger SoC or FPGA-based system.

---

## 2. Inputs and Outputs

### 2.1 Clock and Reset
- `clk`
  - System clock.
  - All internal state updates occur on the rising edge.
- `reset`
  - Synchronous, active-high reset.
  - When asserted, all internal registers are reset on the next rising clock edge.

### 2.2 Encoder Inputs
- `enc_a`
  - Quadrature encoder channel A.
- `enc_b`
  - Quadrature encoder channel B.

Encoder inputs are sampled synchronously on the system clock.

### 2.3 Bus Interface (Abstract)
This peripheral is accessed via a simple memory-mapped interface.

Required abstract signals:
- `bus_addr`   – address
- `bus_wdata`  – write data
- `bus_rdata`  – read data
- `bus_we`     – write enable
- `bus_re`     – read enable


Bus timing and protocol details are implementation-specific and abstracted
for now

---

## 3. Clock/Timing and Reset Assumptions

- All stateful elements update on the rising edge of `clk`.
- Reset is synchronous and sampled on the rising edge.
- When `reset = 1`, all registers, counters, and internal state are reset to
  defined values.
- No state changes occur between clock edges.

---

## 4. Register Map

All registers are 32-bit, word-aligned, memory-mapped registers.
All reset values are 0

| Offset | Name     | R/W | Reset Value | Description |
|------:|----------|:--:|-------------|-------------|
| 0x00  | CTRL     | R/W | 0x00000000  | Control register |
| 0x04  | STATUS   | R   | 0x00000000  | Status register |
| 0x08  | POSITION | R   | 0x00000000  | Signed position count |
| 0x0C  | VELOCITY | R   | 0x00000000  | Signed velocity (counts per window) |

---

## 5. Register Bit Definitions

### 5.1 CTRL Register (0x00)
| Bit | Name     | Description |
|----:|----------|-------------|
| 0   | ENABLE   | Enables encoder counting when set to 1 |
| 1   | CLR_POS  | Writing 1 clears POSITION on next clock edge (self-clearing) |
| 31:2 | —       | Reserved (read as 0) |

**Behaviour**
- When `ENABLE = 0`, encoder transitions are ignored and POSITION/VELOCITY
  remain unchanged.
- `CLR_POS` is self-clearing; hardware clears it automatically after execution.

---

### 5.2 STATUS Register (0x04)
| Bit | Name      | Description |
|----:|-----------|-------------|
| 0   | DIRECTION | Direction of last valid step (1 = forward, 0 = reverse) |
| 31:1 | —        | Reserved (read as 0) |

---

### 5.3 POSITION Register (0x08)
- Signed 32-bit position count.
- Incremented or decremented on each valid quadrature transition.
- Reset to 0 on reset or when `CLR_POS` is asserted.

---

### 5.4 VELOCITY Register (0x0C)
- Signed 32-bit value.
- Represents the change in POSITION over a fixed measurement window.
- Units: encoder counts per window.

---

## 6. Velocity Measurement Definition

Velocity is computed using a fixed time window defined in clock cycles.

Internal behaviour:
- A window counter increments each clock cycle.
- When the counter reaches `WINDOW_CYCLES`:
  - `VELOCITY <= POSITION - PREV_POSITION_WINDOW`
  - `PREV_POSITION_WINDOW <= POSITION`
  - Window counter resets to zero

Notes:
- `WINDOW_CYCLES` is configurable to adapt for various clock speeds.
- VELOCITY is updated periodically, not continuously.
- No division is performed in hardware.Velocity is related to a set amount of clock cycles

---

## 7. Quadrature Decoding Behavior

- Encoder inputs `enc_a` and `enc_b` are sampled each clock.
- The current encoder state is defined as `{enc_a, enc_b}`.
- Direction and movement are determined by comparing the previous and current
  encoder states using a state transition table.
- Valid transitions produce:
  - `+1` position increment for forward
  - `-1` position decrement for reverse
- Invalid transitions are ignored.


## Quadrature Encoder State Transitions

**Forward sequence (x4 decoding):**

00 → 01 → 11 → 10 → 00 →

**Reverse sequence :**

00 → 10 → 11 → 01 → 00 →

### Transition Table
 


| `ab_prev ->  ab_curr` | `00` | `01` | `11` | `10` |
|---------------------|-----:|-----:|-----:|-----:|
| **00**              | 0    | +1   | 0    | −1   |
| **01**              | −1   | 0    | +1   | 0    |
| **11**              | 0    | −1   | 0    | +1   |
| **10**              | +1   | 0    | −1   | 0    |



---

## 8. Reset Behavior Summary

On reset:
- ENABLE = 0
- POSITION = 0
- VELOCITY = 0
- STATUS = 0
- Internal counters and previous encoder state cleared

---

