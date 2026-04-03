# Phase 2 Handoff — Encoder Peripheral Project

## Status
- **Phase 1: COMPLETE** — dummy AXI IP read/write (0xDEADBEEF) and button polling confirmed working on hardware.
- **Phase 2: READY TO START** — all steps below are unstarted.

---

## Project Paths
- Vivado project: `/home/mariop/Documents/Programming/encoder-peripheral/vivado/`
- RTL source files: `/home/mariop/Documents/Programming/encoder-peripheral/rtl/`
- Vitis workspace: `/home/mariop/Documents/Programming/encoder-peripheral/vitis_workspace/`
- Reference (working Phase 1 project): `/home/mariop/Documents/FPGALearning/`

---

## Hardware
- Board: Digilent Cora Z7-07S (Zynq-7000 SoC)
- BTN0: pin D20 → will be wired to `enc_a`
- BTN1: pin D19 → will be wired to `enc_b`
- IOSTANDARD: LVCMOS33 for both

---

## Custom IP Files (already written, tested in simulation)
Located in `rtl/`:
- `encoder_axi.v` — top-level AXI4-Lite slave (handwritten, NOT a Vivado template). Ports: full S_AXI_* interface + `enc_a`, `enc_b`.
- `encoder_core.v` — quadrature decoder with 2-FF synchronizer, position/velocity/direction outputs. WINDOW_CYCLES=100_000_000 (1s at 100MHz).
- `encoder_mmio.v` — register file, instantiates encoder_core.

## Encoder Register Map
| Offset | Register | Access | Description |
|--------|----------|--------|-------------|
| 0x00   | CTRL     | R/W    | bit0=ENABLE, bit1=CLR_POS (pulse) |
| 0x04   | STATUS   | R      | bit0=direction (1=FWD, 0=REV) |
| 0x08   | POSITION | R      | signed 32-bit count |
| 0x0C   | VELOCITY | R      | signed 32-bit counts/window |

---

## Phase 2 Steps (all unstarted)

### Step 1 — Package the Custom IP in Vivado
- Tools → Create and Package New IP → **Package a specified directory**
- Directory: `/home/mariop/Documents/Programming/encoder-peripheral/rtl`
- Check "Import IP files into IP directory"
- In Package IP dialog:
  - **Identification:** name=`encoder_axi`, version=`1.0`
  - **Ports and Interfaces:** verify S_AXI auto-detected as AXI4LITE slave; `enc_a`/`enc_b` should be plain inputs with no interface assigned
  - **Addressing:** confirm range 0x00–0x3F
  - Click **Package IP**

### Step 2 — Update the Block Design
- Delete: `my_dummy_axi_0`, `axi_gpio_0`, `buttons` external port
- Add: `encoder_axi` IP
- Run Connection Automation → connect S_AXI (auto-wires clock, reset, interconnect)
- Right-click `enc_a` port → Make External → name `enc_a`
- Right-click `enc_b` port → Make External → name `enc_b`
- Validate Design (expect 0 errors)

### Step 3 — Update XDC
Replace entire `cora_z7.xdc` with:
```tcl
# BTN0 -> enc_a (D20)
set_property -dict { PACKAGE_PIN D20 IOSTANDARD LVCMOS33 } [get_ports { enc_a }];

# BTN1 -> enc_b (D19)
set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports { enc_b }];
```

### Step 4 — Generate Bitstream and Export XSA
- Generate Bitstream (let full flow run)
- In Tcl Console, force XSA output location:
```tcl
write_hw_platform -fixed -include_bit -force \
  /home/mariop/Documents/Programming/encoder-peripheral/vivado/design_1_wrapper.xsa
```

### Step 5 — Update Vitis
> **CRITICAL: Close Vivado Hardware Manager target before switching to Vitis.**
- Right-click `cora_platform` → Update Hardware Specification → point to new `.xsa`
- Build the platform
- Verify `XPAR_ENCODER_AXI_0_BASEADDR` exists in `xparameters.h`
> **CRITICAL: Check Run/Debug Configuration → Bitstream tab points to the new `design_1_wrapper.bit` in `impl_1/`, not a stale path.**

### Step 6 — Phase 2 Test Code
```c
#include <stdio.h>
#include <stdint.h>
#include "xil_printf.h"
#include "xparameters.h"

#define ENC_BASE     XPAR_ENCODER_AXI_0_BASEADDR

#define REG_CTRL     *((volatile uint32_t *)(ENC_BASE + 0x00))
#define REG_STATUS   *((volatile uint32_t *)(ENC_BASE + 0x04))
#define REG_POSITION *((volatile int32_t  *)(ENC_BASE + 0x08))
#define REG_VELOCITY *((volatile int32_t  *)(ENC_BASE + 0x0C))

#define CTRL_ENABLE   (1 << 0)
#define CTRL_CLR_POS  (1 << 1)

int main(void)
{
    xil_printf("\r\n=== Phase 2: Encoder Test ===\r\n");

    REG_CTRL = CTRL_CLR_POS;
    REG_CTRL = CTRL_ENABLE;

    xil_printf("Encoder enabled. Tap BTN0/BTN1 to simulate quadrature pulses.\r\n");
    xil_printf("Polling for 30 seconds...\r\n\r\n");

    for (int i = 0; i < 150; i++) {
        int32_t pos = REG_POSITION;
        int32_t vel = REG_VELOCITY;
        uint32_t dir = REG_STATUS & 0x1;

        xil_printf("pos=%6d  vel=%6d  dir=%s\r\n",
                   pos, vel, dir ? "FWD" : "REV");

        for (volatile int d = 0; d < 2000000; d++);
    }

    REG_CTRL = 0;
    xil_printf("Done.\r\n");
    return 0;
}
```

---

## Known Toolchain Traps
1. **Vivado HW Manager vs Vitis FTDI conflict:** Always close the Vivado Hardware Manager target before running/debugging in Vitis, or picocom crashes.
2. **Stale .bit file in Vitis Launch Config:** After regenerating bitstream, manually verify the Run/Debug Configuration bitstream path points to the new `impl_1/design_1_wrapper.bit`.
3. **XSA export location:** Use the Tcl command above — the GUI dialog sometimes greys out the path selector.
4. **AXI GPIO TRI register:** For future reference — even with "All Inputs" configured in IP wizard, software must write 0xFFFFFFFF to base+0x04 before reading. (Not relevant for Phase 2, encoder IP handles direction internally.)
