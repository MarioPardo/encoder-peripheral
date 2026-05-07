#include <stdio.h>
#include <fcntl.h>
#include <linux/i2c-dev.h>
#include <sys/ioctl.h>
#include <unistd.h>

int main(void) {
    int fd = open("/dev/i2c-0", O_RDWR);
    if (fd < 0) { perror("open"); return 1; }

    printf("Scanning /dev/i2c-0...\n");
    for (int addr = 0x03; addr <= 0x77; addr++) {
        if (ioctl(fd, I2C_SLAVE, addr) < 0) continue;
        char buf = 0;
        if (write(fd, &buf, 1) >= 0)
            printf("Found device at 0x%02X\n", addr);
    }
    printf("Done.\n");
    close(fd);
    return 0;
}
