# Phase 4 Handoff — UIO Driver + GME12864 Display

## Status
- **Phase 1: COMPLETE** — dummy AXI read/write confirmed on hardware
- **Phase 2: COMPLETE** — custom encoder_axi RTL, KY-040 wired to PMOD JA, position/velocity/direction working
- **Phase 3: COMPLETE** — embedded Linux booting on Cora Z7, encoder readable from userspace via /dev/mem
- **Phase 4A: COMPLETE** — UIO driver working, encoder readable via /dev/uio0 without sudo
- **Phase 4B: IN PROGRESS** — GME12864 SSD1306 I2C display, pending rebuild + Linux driver

---

## Working Environment
- Docker container: `petalinux:2025.2`
- Start container:
  ```bash
  docker run -it --privileged -v /home/mariop/Documents/Programming/encoder-peripheral:/workspace petalinux:2025.2 bash
  ```
- Inside container, always run first:
  ```bash
  ln -s /workspace/petalinux/cora_linux /home/plnx/cora_linux
  export PATH=$PATH:/workspace/petalinux/cora_linux/components/yocto/layers/meta-xilinx/meta-xilinx-core/gen-machine-conf
  source /home/plnx/petalinux/settings.sh
  cd /workspace/petalinux/cora_linux
  ```
- PetaLinux project: `/home/mariop/Documents/Programming/encoder-peripheral/petalinux/cora_linux`
- Board login: `petalinux` / `pass`
- UART: `picocom -b 115200 /dev/ttyUSB1` (try ttyUSB0 if that fails)
- Board IP: `192.168.1.2` (static, baked into rootfs via init-ifupdown recipe)
- PC IP: `sudo ip addr add 192.168.1.1/24 dev eno1 && sudo ip link set eno1 up`

---

## Phase 4A — UIO Driver (COMPLETE)

### What was done
- `system-user.dtsi` updated: encoder node referenced by label `&encoder_axi_0`, `compatible = "generic-uio"`
  - Key lesson: auto-generated `pl.dtsi` already has the node as `encoder_axi_0` — must reference by label, not create a new node under `&amba` (causes duplicate sysfs error)
- `uio_pdrv_genirq` enabled in kernel config (`CONFIG_UIO_PDRV_GENIRQ=y`)
- Bootargs set in `system-user.dtsi` chosen node: `uio_pdrv_genirq.of_id=generic-uio`
  - Key lesson: `uio_pdrv_genirq` does NOT auto-bind via compatible string in this kernel build — requires `of_id` module parameter
- `encoder_read_uio.c` written, searches `/sys/class/uio/*/name` for `"encoder_axi@40000000"` (not `"encoder_axi"` — sysfs appends the address)
- Cross-compiled: `arm-linux-gnueabihf-gcc -o c_code/encoder_read_uio c_code/encoder_read_uio.c`
- Confirmed working on hardware — no sudo needed

### Current system-user.dtsi
```dts
/include/ "system-conf.dtsi"
/ {
    chosen {
        bootargs = "console=ttyPS0,115200 earlycon root=/dev/mmcblk0p2 ro rootwait uio_pdrv_genirq.of_id=generic-uio";
    };
};

&encoder_axi_0 {
    compatible = "generic-uio";
};

&i2c1 {
    status = "okay";
    clock-frequency = <100000>;
};
```

---

## Phase 4B — GME12864 Display (IN PROGRESS — BLOCKED on I2C hardware)

### Display identified
- Controller: **SSD1306**
- Interface: **I2C** (4 pins: GND, VDD, SCK, SDA)
- I2C address: likely **0x3C** (standard SSD1306 default)
- Confirmed working on Arduino using U8g2 library with **software I2C** (hardware I2C doesn't work — display is timing-sensitive)
- VDD: 5V (has onboard regulator)

### Wiring to Cora Z7 (Arduino shield header)
| Display Pin | Cora Z7 Pin |
|-------------|-------------|
| GND | GND |
| VDD | 5V0 |
| SCK | A5 (SCL) |
| SDA | A4 (SDA) |

These pins map to PS I2C1 controller (`e0005000`, `/dev/i2c-0` in Linux).

### Current state after rebuild + flashing
- `/dev/i2c-0` exists, `dmesg` shows: `cdns-i2c e0005000.i2c: 100 kHz mmio e0005000 irq 38` — controller initialized
- `/dev/uio0` exists, encoder confirmed still working
- Static IP **did not bake in** — must set manually every boot (see below)
- `i2cdetect` not available on board — use `sudo ./i2c_scan` instead

### I2C problem — BLOCKED
A4 and A5 read **~1.1V with nothing connected** — the PS I2C controller is holding the lines low. This prevents any I2C transaction from completing (every transaction times out after several seconds).

Things already tried:
- 4.7kΩ pull-up resistors from SDA and SCL to 3.3V — did not help
- `modprobe -r cdns_i2c` — module is built-in, cannot unload
- `i2c_scan` with `write()` probe — hangs on every address due to timeout

Root cause hypothesis: **MIO pin mux may not be configured for I2C in the Vivado PS7 block**. The device tree enables I2C1 but if Vivado didn't route I2C1 signals to the correct MIO pins (Arduino A4/A5), the controller has no physical connection and drives the lines to an undefined state.

### Next step — Vitis bare metal test (Option A)
Write a standalone Vitis C app using `XIicPs` driver to:
1. Initialize PS I2C1 at 100kHz
2. Scan for device at 0x3C
3. If found, send SSD1306 init sequence and display something

If bare metal works → Vivado PS7 config is fine, problem is Linux-side
If bare metal also fails → open Vivado, check PS7 I2C1 MIO pin assignments

Existing Vivado project: reopen from `encoder-peripheral` repo, same bitstream as Phase 2/3/4A.

### Rebuild steps (already done, for reference)
```bash
# Inside docker container (after setup commands)
petalinux-build
petalinux-package --boot --fsbl --fpga --u-boot --force
```

Flash boot + rootfs:
```bash
sudo mount /dev/sda1 /mnt/boot
sudo cp images/linux/BOOT.BIN images/linux/boot.scr images/linux/image.ub /mnt/boot/
sync && sudo umount /mnt/boot
sudo dd if=images/linux/rootfs.ext4 of=/dev/sda2 bs=4M status=progress && sync
```

### Manual IP setup (static IP recipe not working yet)
Every boot, on board:
```bash
sudo ip addr add 192.168.1.2/24 dev enx000a35001e53
sudo ip link set enx000a35001e53 up
```
On PC host:
```bash
sudo ip addr add 192.168.1.1/24 dev eno1 && sudo ip link set eno1 up
```

### Static IP recipe bug (unfixed)
`project-spec/meta-user/recipes-core/init-ifupdown/init-ifupdown_%.bbappend` was using `SRC_URI =` (replace) instead of `SRC_URI:append =`. Fixed the license checksum build error but the static IP still doesn't survive reboot — needs further investigation.

### After I2C is confirmed working (post bare metal test)
1. Write userspace SSD1306 driver in C (I2C via `/dev/i2c-0`)
   - Use 100kHz, may need delays between commands
2. Display encoder data (position, velocity, direction) on screen
3. Combine `encoder_read_uio` + display into single app

---

## Known Traps
1. Docker container loses the symlink and PATH on every restart — always run the 3 setup commands above first
2. Board network interface is named `enx000a35001e53` (MAC-based), not `eth0`
3. PetaLinux version must match Vivado version (both 2025.2)
4. Board login is `petalinux`/`pass` — NOT root/root (root login disabled by default)
5. UART device shifts between ttyUSB0/ttyUSB1 when Ethernet cable is plugged in — try both
6. Cross-compile on host with `arm-linux-gnueabihf-gcc`, not on board (no gcc installed)
7. Encoder base address: `0x40000000` — confirmed from Vivado address editor
8. PL clock is 50MHz — WINDOW_CYCLES=100_000_000 means 2s velocity window, not 1s
9. BitBake PermissionError on `/proc/self/uid_map`: caused by Ubuntu 24.04 AppArmor restricting unprivileged user namespaces. Fix: `sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0` on host. Make permanent: `echo 'kernel.apparmor_restrict_unprivileged_userns=0' | sudo tee /etc/sysctl.d/99-userns.conf`
10. `uio_pdrv_genirq` does not auto-bind via compatible string — requires `of_id=generic-uio` kernel parameter (set in bootargs chosen node)
11. UIO sysfs device name is `encoder_axi@40000000` (not `encoder_axi`) — search string in encoder_read_uio.c must match exactly
12. SSD1306 display is timing-sensitive — hardware I2C fails silently, use 100kHz. On Arduino, software I2C (U8g2 SW_I2C) was required. May need extra delays in Linux userspace driver.
13. `sudo echo ... > /sys/...` doesn't work — shell redirect runs before sudo. Use `echo ... | sudo tee /sys/...` instead
14. Device tree duplicate node trap: auto-generated `pl.dtsi` already defines `encoder_axi_0`. Adding a new node under `&amba` in `system-user.dtsi` causes duplicate sysfs error. Always reference existing nodes by label.
15. `init-ifupdown` bbappend must use `SRC_URI:append = " file://interfaces"` (not `SRC_URI =`) — replacing SRC_URI drops the `copyright` file and breaks the license checksum QA check.
16. I2C scan using `read()` blocks forever on missing devices — use `write()` probe instead. Even with `write()`, each address takes several seconds to timeout if the bus is stuck (no pull-ups or lines held low). Add 4.7kΩ pull-ups to 3.3V on SDA and SCL for fast NACK behavior.
17. `/dev/i2c-0` requires sudo — run `sudo ./i2c_scan`, not `./i2c_scan`.
18. `cdns_i2c` is built into the kernel (not a module) — `modprobe -r cdns_i2c` will fail. Cannot reset the I2C controller from userspace.
