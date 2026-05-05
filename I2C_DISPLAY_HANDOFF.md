# I2C Display Handoff

## Goal
1. Bare metal: drive SSD1306 display from Zynq PS I2C at reduced clock speed
2. Bare metal: combine display with encoder — show live position on screen
3. Embedded Linux: repeat both steps from userspace

---

## Display Hardware Facts
| Property | Value |
|----------|-------|
| Module | SSD1306 128x64 OLED |
| I2C Address | 0x3C |
| I2C Clock | ~10kHz (default 100kHz silently fails) |
| Library (Arduino ref) | Adafruit SSD1306 + Adafruit GFX |

**Root cause of original failure:** Clock speed only. All libraries (Adafruit, U8g2) and both HW/SW I2C modes work once clock is reduced. The display is timing-sensitive — 100kHz is too fast.

---

## Pin Assignment
Use the Zynq PS I2C controller (MIO pins) — no PL GPIO or AXI GPIO needed.

Cora Z7 PS I2C pins (MIO, exposed on Arduino header):
| Signal | Arduino Header Pin |
|--------|--------------------|
| SCL    | A5 (SCL)           |
| SDA    | A4 (SDA)           |

Wire the display: SCL→A5, SDA→A4, VCC→3.3V, GND→GND.

> No Vivado changes needed — PS I2C is part of the PS and always available.
> No new bitstream required for Step 1.

---

## Step 1 — Bare Metal: Display Only

### Vitis
Use the `XIicPs` driver (included in BSP automatically).

Key steps:
1. Look up the PS I2C base address in `xparameters.h` — typically `XPAR_XIICPS_0_BASEADDR`
2. Init with `XIicPs_CfgInitialize()`
3. Set clock with `XIicPs_SetSClk()` — target **~10000 Hz**
4. Send SSD1306 init sequence via `XIicPs_MasterSendPolled()`
5. Send display data the same way

**SSD1306 init sequence (minimum):**
```c
// Each entry sent as: address=0x3C, buf={0x00, cmd}
0xAE        // display off
0x20, 0x00  // horizontal addressing mode
0xB0        // page start
0xC8        // COM scan direction
0x00, 0x10  // column address low/high
0x40        // start line
0x81, 0xFF  // contrast max
0xA1        // segment remap
0xA6        // normal display
0xA8, 0x3F  // multiplex ratio
0xA4        // output from RAM
0xD3, 0x00  // display offset = 0
0xD5, 0xF0  // clock divide ratio
0xD9, 0x22  // pre-charge period
0xDA, 0x12  // COM pins
0xDB, 0x20  // VCOMH
0x8D, 0x14  // charge pump on
0xAF        // display on
```

**Test goal:** display shows "HELLO ZYNQ".

### Lessons to Record After Step 1
- Exact `XIicPs_SetSClk()` value that worked
- Whether polled mode was sufficient or interrupt mode was needed
- Any BSP config needed to enable IIC in the platform

---

## Step 2 — Bare Metal: Encoder + Display

No hardware or Vivado changes needed.

In Vitis:
- Encoder registers at base `0x40000000` (CTRL/STATUS/POSITION/VELOCITY — see PHASE3_HANDOFF.md)
- Enable encoder: write `0x1` to CTRL (offset 0x00)
- Read `POSITION` (offset 0x08) every ~100ms
- Format: `snprintf(buf, sizeof(buf), "POS: %ld", pos)`
- Send string to display

**Test goal:** turn encoder, position updates live on screen.

### Lessons to Record After Step 2
- Display refresh rate vs encoder polling — any flicker?
- Whether full clear each frame causes flicker (may need partial update)

---

## Step 3 — Embedded Linux: Display

The Zynq PS I2C controller appears in Linux as `/dev/i2c-0` (or `/dev/i2c-1`).  
The clock frequency is set in the device tree — add an override in `system-user.dtsi`:

```dts
&i2c0 {
    clock-frequency = <10000>;
};
```

### Userspace
```c
int fd = open("/dev/i2c-0", O_RDWR);
ioctl(fd, I2C_SLAVE, 0x3C);
// send init sequence and data via write()
```

Same byte sequences as bare metal — just file I/O instead of XIicPs calls.

**Test goal:** userspace C app displays text via Linux PS I2C.

### Lessons to Record After Step 3
- Which `/dev/i2c-N` number maps to PS I2C0
- Whether `clock-frequency = <10000>` in device tree was respected
- Whether raw i2c-dev write worked or a proper ssd1306 kernel driver was needed

---

## Step 4 — Embedded Linux: Encoder + Display Combined

- Encoder: `/dev/mem` at `0x40000000` (see PHASE3_HANDOFF.md)
- Display: `/dev/i2c-0` at `0x3C`
- One C app: poll encoder, format string, push to display

**Test goal:** same as Step 2 but running on Linux userspace.

---

## Reference
- Encoder register map and `/dev/mem` app: `PHASE3_HANDOFF.md`
- Arduino verified test: `arduino/arduino_i2cdisp_test.c`
- Display facts: `docs/i2cdisplayinfo.md`
