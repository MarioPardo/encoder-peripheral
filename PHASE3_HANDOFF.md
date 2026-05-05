# Phase 3 Handoff — Embedded Linux

## Status
- **Phase 1: COMPLETE** — dummy AXI read/write confirmed on hardware
- **Phase 2: COMPLETE** — custom encoder_axi RTL, KY-040 wired to PMOD JA, position/velocity/direction working
- **Phase 3: READY TO START** — bring up embedded Linux on Cora Z7, access encoder from userspace

---

## Project Paths
- Vivado project: `/home/mariop/Documents/Programming/encoder-peripheral/vivado/`
- RTL source files: `/home/mariop/Documents/Programming/encoder-peripheral/rtl/`
- Vitis workspace: `/home/mariop/Documents/Programming/encoder-peripheral/vitis_workspace/`
- Hardware export: `/home/mariop/Documents/Programming/encoder-peripheral/vivado/design_1_wrapper.xsa`

---

## Hardware
- Board: Digilent Cora Z7-07S (Zynq-7000 SoC)
- Encoder: KY-040 rotary encoder (3.3V)
- PMOD JA1 (Y18) → CLK → enc_a
- PMOD JA2 (Y19) → DT  → enc_b
- PMOD JA pin 6 → VCC (3.3V)
- PMOD JA pin 5 → GND

---

## Encoder Register Map
| Offset | Register | Access | Description |
|--------|----------|--------|-------------|
| 0x00   | CTRL     | R/W    | bit0=ENABLE, bit1=CLR_POS (pulse) |
| 0x04   | STATUS   | R      | bit0=direction (1=FWD, 0=REV) |
| 0x08   | POSITION | R      | signed 32-bit count |
| 0x0C   | VELOCITY | R      | signed 32-bit counts/window (1s at 50MHz=50_000_000 cycles) |

> **Note:** WINDOW_CYCLES in encoder_core.v is set to 100_000_000 but the PL clock is 50MHz (FCLK_CLK0). Velocity window is therefore 2 seconds, not 1. Fix in a future cleanup if needed.

---

## Phase 3 Steps

### Step 1 — Install PetaLinux
- PetaLinux 2025.2 to match Vivado version
- Requires Ubuntu 20.04 or 22.04 (check Xilinx compatibility matrix)
- Download from Xilinx/AMD downloads page (requires account)
- Install: `./petalinux-v2025.2-installer.run --dir ~/petalinux/2025.2`
- Source before use: `source ~/petalinux/2025.2/settings.sh`

### Step 2 — Create PetaLinux Project
```bash
petalinux-create --type project --template zynq --name cora_linux
cd cora_linux
petalinux-config --get-hw-description /home/mariop/Documents/Programming/encoder-peripheral/vivado/design_1_wrapper.xsa
```
- In the config menu: set boot device to SD card, set root filesystem to EXT4

### Step 3 — Add Device Tree Entry for Encoder
Edit `project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi`:
```dts
&amba {
    encoder_axi@40000000 {
        compatible = "mario,encoder-axi";
        reg = <0x40000000 0x10>;
    };
};
```

### Step 4 — Build
```bash
petalinux-build
```
This builds: FSBL, U-Boot, Linux kernel, rootfs, device tree blob.

### Step 5 — Package for SD Card
```bash
petalinux-package --boot --fsbl --fpga --u-boot --force
```
SD card layout:
- Partition 1 (FAT32): `BOOT.BIN`, `boot.scr`, `image.ub`
- Partition 2 (EXT4): rootfs

Flash with:
```bash
petalinux-package --wic --wic-swap-rootfs
# or manually dd the rootfs
```

### Step 6 — Boot and Verify
- Connect via UART (picocom -b 115200 /dev/ttyUSB1)
- Should see U-Boot then Linux login
- Default credentials: root / root (PetaLinux default)
- Verify encoder device exists: `ls /sys/bus/platform/devices/ | grep 40000000`

### Step 7 — Read Encoder from Userspace via /dev/mem
```c
#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#define ENC_BASE    0x40000000
#define MAP_SIZE    0x10
#define CTRL_ENABLE (1 << 0)
#define CTRL_CLR    (1 << 1)

int main(void) {
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    volatile uint32_t *enc = mmap(NULL, MAP_SIZE,
                                  PROT_READ | PROT_WRITE,
                                  MAP_SHARED, fd, ENC_BASE);

    enc[0] = CTRL_CLR;    // clear position
    enc[0] = CTRL_ENABLE; // enable

    for (int i = 0; i < 30; i++) {
        int32_t pos = (int32_t)enc[2];
        int32_t vel = (int32_t)enc[3];
        uint32_t dir = enc[1] & 0x1;
        printf("pos=%6d  vel=%6d  dir=%s\n", pos, vel, dir ? "FWD" : "REV");
        sleep(1);
    }

    munmap((void*)enc, MAP_SIZE);
    close(fd);
    return 0;
}
```
Compile on board: `gcc encoder_read.c -o encoder_read`
Run: `./encoder_read` (may need root or `/dev/mem` permissions)

### Step 8 — (Next) Move to UIO Driver
- Add `uio_pdrv_genirq` to kernel config
- Add `uio_pdrv_genirq` compatible string to device tree
- Access via `/dev/uio0` instead of `/dev/mem`
- Cleaner, no raw physical memory access

---

## Known Traps
1. **PetaLinux version must match Vivado version** — mismatches cause subtle build failures
2. **XSA must be re-imported** if block design changes — `petalinux-config --get-hw-description <new.xsa>`
3. **Encoder base address is 0x40000000** — confirmed from Vivado address editor
4. **PL clock is 50MHz** — WINDOW_CYCLES=100_000_000 means 2s velocity window, not 1s
5. **/dev/mem access may require root** — `sudo ./encoder_read` or add user to kmem group
