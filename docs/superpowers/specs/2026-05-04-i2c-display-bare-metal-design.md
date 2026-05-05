# I2C Display — Bare Metal (Step 1) Design

## Goal

Drive an SSD1306 128×64 OLED from the Zynq PS I2C controller in bare-metal Vitis,
displaying "HELLO ZYNQ". Encoder functionality stays intact; Step 2 (show encoder
position on display) follows after Step 1 is confirmed on hardware.

## Hardware

| Signal | Pin |
|--------|-----|
| SCL | Arduino A5 (MIO, PS I2C0) |
| SDA | Arduino A4 (MIO, PS I2C0) |
| VCC | 3.3 V |
| GND | GND |

I2C address: `0x3C`. Required clock: ~10 kHz (default 100 kHz silently fails).
No Vivado/bitstream changes needed — PS I2C is always available.

## Files

All changes are within `vitis_workspace/phase1_test/src/`:

```
src/
├── main.c              ← modified
├── ssd1306_font.h      ← new
└── ssd1306.h           ← new
```

## Architecture

### ssd1306_font.h

`uint8_t font5x7[][5]` table indexed from ASCII 0x20 (space). Each entry is
5 bytes — column bitmaps for one character, LSB = top pixel.

### ssd1306.h

Header-only driver (no separate `.c` to avoid Vitis project changes). Three functions,
all taking a `XIicPs *` owned by `main.c`:

- `ssd1306_init(XIicPs *iic)` — sends 18-command init sequence; sets clock to 10 kHz
- `ssd1306_clear(XIicPs *iic)` — writes 0x00 to all 8 pages × 128 columns
- `ssd1306_draw_string(XIicPs *iic, uint8_t col, uint8_t page, const char *str)` —
  renders each character as 5 column bytes + 1 spacer at the given position

All I2C sends use `XIicPs_MasterSendPolled()` to address `0x3C`.

### main.c (Step 1)

1. Init `XIicPs` via `XIicPs_CfgInitialize()` using `XPAR_XIICPS_0_BASEADDR`
2. Set clock to 10 kHz via `XIicPs_SetSClk()`
3. Call `ssd1306_init()`
4. Call `ssd1306_draw_string()` → `"HELLO ZYNQ"` at page 0, col 0
5. `while(1)` — hang, display stays on

Existing encoder register defines and `xil_printf` loop are left untouched above;
Step 1 code runs before them (display init is independent of the encoder).

## Step 2 (follow-up, after hardware confirmation)

Replace the `while(1)` hang with:
- Enable encoder (write `CTRL_ENABLE` to `REG_CTRL`)
- Loop: read `REG_POSITION`, `snprintf` → `"POS: %ld"`, `ssd1306_clear()` +
  `ssd1306_draw_string()`, ~200 ms delay

No new files needed for Step 2 — only `main.c` changes.

## Key Constraints

- SSD1306 clock must be ≤ 10 kHz — verify with `XIicPs_SetSClk()` return value
- `XIicPs_MasterSendPolled()` requires the bus to be idle; check return status
- Font table covers ASCII 0x20–0x7E; anything outside that range is undefined
