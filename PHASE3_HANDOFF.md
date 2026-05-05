# Phase 3 Handoff — New Machine Setup + Embedded Linux

## Status

| Phase | Status |
|-------|--------|
| Phase 1 — dummy AXI read/write | COMPLETE |
| Phase 2 — custom encoder_axi RTL | COMPLETE |
| Bare metal: I2C display only | COMPLETE |
| Bare metal: encoder + display | COMPLETE |
| **Phase 3 — embedded Linux** | **NEXT** |

---

## Hardware

- **Board:** Digilent Cora Z7-07S (Zynq-7000 SoC)
- **Encoder:** KY-040 rotary encoder
  - PMOD JA1 (Y18) → CLK → enc_a
  - PMOD JA2 (Y19) → DT  → enc_b
  - PMOD JA pin 6 → VCC (3.3V)
  - PMOD JA pin 5 → GND
- **Display:** SSD1306 128x64 OLED (I2C address 0x3C)
  - Arduino SCL header (P16) → SCL
  - Arduino SDA header (P15) → SDA
  - VCC → 3.3V, GND → GND
  - **Do NOT use the MIO I2C pins** — MIO bank 1 is 1.8V, kills the display
  - PS I2C0 is routed via EMIO → PL → Arduino header (3.3V)

---

## Encoder Register Map

| Offset | Register | Access | Description |
|--------|----------|--------|-------------|
| 0x00   | CTRL     | R/W    | bit0=ENABLE, bit1=CLR_POS (pulse) |
| 0x04   | STATUS   | R      | bit0=direction (1=FWD, 0=REV) |
| 0x08   | POSITION | R      | signed 32-bit count |
| 0x0C   | VELOCITY | R      | signed 32-bit counts/window |

> Base address: **0x40000000**
> WINDOW_CYCLES=100_000_000 at 50MHz PL clock = **2s velocity window**

---

## Step 1 — New Machine: Vivado Setup

```bash
git pull
```

Open Vivado → File → Open Project → `vivado/encoder_peripheral.xpr`

Vivado will prompt to regenerate outputs — say yes. Then:

**Synthesis + Implementation + Bitstream:** Flow → Generate Bitstream (~10–15 min)

> The `.xpr`, `.bd`, `.xci`, `.xsa`, `.xdc` are all tracked in git — no manual changes needed.
> The bitstream is not tracked (it's in `vivado/*.runs/` which is gitignored) so it must be regenerated.

---

## Step 2 — New Machine: Vitis Setup

Open Vitis 2025.2 → open workspace `vitis_workspace/`

The `phase1_test` application and `cora_platform` are tracked. You may need to re-associate the platform with the new XSA:

1. Right-click `cora_platform` → Update Hardware Specification → point to `vivado/design_1_wrapper.xsa`
2. Right-click `cora_platform` → Build
3. Right-click `phase1_test` → Build

> Source files are in `vitis_workspace/phase1_test/src/`:
> - `main.c` — encoder + display app
> - `ssd1306.h` / `ssd1306_font.h` — display driver

---

## Step 3 — Bare Metal Verification

Flash the board and verify the bare metal app still works before touching PetaLinux.

**Expected behavior:**
- UART (115200 baud, picocom -b 115200 /dev/ttyUSB1) prints `=== Step 2: Encoder + Display ===`
- Display shows `POS`, `VEL`, `DIR`
- Turning the encoder updates values on display and UART in real time

**I2C notes:**
- Clock set to 50kHz (`SSD1306_I2C_HZ` in `ssd1306.h`) — 100kHz silently fails
- `XIicPs_LookupConfig` takes `XPAR_XIICPS_0_BASEADDR` (SDT, not DEVICE_ID)
- No `while(XIicPs_BusIsBusy())` loops — they hang on NACK
- Serial monitor: close/kill Vitis debug session before opening picocom or it holds the UART

---

## Step 4 — PetaLinux: Docker Setup

PetaLinux must run inside Docker. The Docker setup lives at `~/Documents/petalinux-docker/`.

**Build the image (one-time, ~20–30 min):**
```bash
cd ~/Documents/petalinux-docker
docker build -t petalinux:2025.2 .
```

The Dockerfile installs PetaLinux 2025.2 into `/home/plnx/petalinux/` inside the container.

---

## Step 5 — PetaLinux: Create Project

Run all petalinux commands via Docker, mounting the project directory:

```bash
# Create the project
docker run --rm -v /home/mariop/Documents/Programming/encoder-peripheral/petalinux:/work \
  petalinux:2025.2 bash -c "
    source /home/plnx/petalinux/settings.sh &&
    cd /work &&
    petalinux-create --type project --template zynq --name cora_linux
  "

# Import hardware description
docker run --rm \
  -v /home/mariop/Documents/Programming/encoder-peripheral/petalinux:/work \
  -v /home/mariop/Documents/Programming/encoder-peripheral/vivado:/xsa \
  petalinux:2025.2 bash -c "
    source /home/plnx/petalinux/settings.sh &&
    cd /work/cora_linux &&
    petalinux-config --get-hw-description /xsa/design_1_wrapper.xsa --silentconfig
  "
```

> In the config menu (if it opens): set boot device = SD card, rootfs = EXT4.
> The `--silentconfig` flag skips the menu — remove it if you want to inspect settings.

---

## Step 6 — PetaLinux: Device Tree

Copy the pre-written device tree overlay into the project:

```bash
cp devicetree/system-user.dtsi \
   petalinux/cora_linux/project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi
```

Contents of `devicetree/system-user.dtsi` (already in git):
```dts
/include/ "system-conf.dtsi"
/ {
};

&i2c0 {
    clock-frequency = <50000>;
};

&amba {
    encoder_axi@40000000 {
        compatible = "mario,encoder-axi";
        reg = <0x40000000 0x10>;
    };
};
```

> `&i2c0` sets the PS I2C0 clock to 50kHz — matches bare metal, 100kHz fails.
> `encoder_axi@40000000` registers the encoder in the device tree for userspace visibility.

---

## Step 7 — PetaLinux: Build

```bash
docker run --rm -v /home/mariop/Documents/Programming/encoder-peripheral/petalinux/cora_linux:/work \
  petalinux:2025.2 bash -c "
    source /home/plnx/petalinux/settings.sh &&
    cd /work &&
    petalinux-build
  "
```

This builds: FSBL, U-Boot, Linux kernel, rootfs, device tree blob. Takes **30–60 min**.

---

## Step 8 — PetaLinux: Package for SD Card

```bash
docker run --rm -v /home/mariop/Documents/Programming/encoder-peripheral/petalinux/cora_linux:/work \
  petalinux:2025.2 bash -c "
    source /home/plnx/petalinux/settings.sh &&
    cd /work &&
    petalinux-package --boot --fsbl --fpga --u-boot --force
  "
```

Output files in `petalinux/cora_linux/images/linux/`:
- `BOOT.BIN` → FAT32 partition
- `image.ub` → FAT32 partition
- `boot.scr` → FAT32 partition
- `rootfs.ext4` → flash to EXT4 partition

**Flash SD card:**
```bash
# Replace sdX with your SD card device — DOUBLE CHECK before running
sudo dd if=images/linux/rootfs.ext4 of=/dev/sdX2 bs=4M status=progress
# Copy boot files to FAT32 partition (mount it first)
sudo cp images/linux/BOOT.BIN images/linux/image.ub images/linux/boot.scr /mnt/sdcard/
```

---

## Step 9 — Boot and Verify

Connect UART: `picocom -b 115200 /dev/ttyUSB1`

Boot should show U-Boot then Linux login. Default credentials: `root` / `root`

**Verify encoder device:**
```bash
ls /sys/bus/platform/devices/ | grep 40000000
```

**Verify I2C:**
```bash
ls /dev/i2c-*
i2cdetect -y 0   # should show 0x3C at address 0x3c
```

---

## Step 10 — Userspace App: Encoder + Display

Write `encoder_display.c` on the board or cross-compile:

```c
#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>
#include <unistd.h>
#include <string.h>

#define ENC_BASE    0x40000000
#define MAP_SIZE    0x10
#define SSD1306_ADDR 0x3C

/* --- encoder helpers --- */
#define CTRL_ENABLE (1 << 0)
#define CTRL_CLR    (1 << 1)

/* --- minimal SSD1306 init sequence --- */
static const uint8_t ssd1306_init_cmds[] = {
    0xAE, 0x20, 0x00, 0xB0, 0xC8, 0x00, 0x10, 0x40,
    0x81, 0xFF, 0xA1, 0xA6, 0xA8, 0x3F, 0xA4, 0xD3,
    0x00, 0xD5, 0xF0, 0xD9, 0x22, 0xDA, 0x12, 0xDB,
    0x20, 0x8D, 0x14, 0xAF
};

static void i2c_cmd(int fd, uint8_t cmd) {
    uint8_t buf[2] = {0x00, cmd};
    write(fd, buf, 2);
}

int main(void) {
    /* encoder via /dev/mem */
    int mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    volatile uint32_t *enc = mmap(NULL, MAP_SIZE,
        PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, ENC_BASE);
    enc[0] = CTRL_CLR;
    enc[0] = CTRL_ENABLE;

    /* display via /dev/i2c-0 (verify number on board first) */
    int i2c_fd = open("/dev/i2c-0", O_RDWR);
    ioctl(i2c_fd, I2C_SLAVE, SSD1306_ADDR);
    for (size_t i = 0; i < sizeof(ssd1306_init_cmds); i++)
        i2c_cmd(i2c_fd, ssd1306_init_cmds[i]);

    while (1) {
        int32_t pos = (int32_t)enc[2];
        int32_t vel = (int32_t)enc[3];
        const char *dir = (vel > 0) ? "CW " : (vel < 0) ? "CCW" : "---";
        printf("pos=%6d  vel=%6d  dir=%s\n", pos, vel, dir);
        /* TODO: send pos/vel/dir to display via i2c_fd */
        sleep(1);
    }

    munmap((void*)enc, MAP_SIZE);
    close(mem_fd);
    close(i2c_fd);
    return 0;
}
```

Compile on board:
```bash
gcc encoder_display.c -o encoder_display
./encoder_display   # may need: sudo ./encoder_display
```

> The `/dev/i2c-0` number may differ — check `i2cdetect -y 0` and `i2cdetect -y 1`.
> The display write logic above is a stub — wire in the full SSD1306 draw functions from `ssd1306.h` or port them.

---

## Known Traps

1. **PetaLinux version must match Vivado** — both must be 2025.2
2. **Always use Docker** for petalinux commands — host Ubuntu version is wrong
3. **XSA must be re-imported** after any Vivado block design change
4. **sdb1 is NTFS** — cannot use it for Docker data root (overlay2 needs ext4)
5. **Bitstream not in git** — must regenerate in Vivado after pulling on a new machine
6. **I2C clock 100kHz fails silently** — use 50kHz or lower; set via device tree for Linux
7. **`/dev/mem` may need root** — `sudo ./encoder_display` if permission denied
8. **Vitis serial monitor conflicts with picocom** — kill debug session before opening picocom
