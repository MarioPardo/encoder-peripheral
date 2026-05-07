#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <string.h>
#include <dirent.h>

#define MAP_SIZE    0x10 //4 registers, 4 bytes each = 16 bytes = 0x10
#define CTRL_ENABLE (1 << 0)
#define CTRL_CLR    (1 << 1)

int find_uio_device(const char *name, char *out_path, size_t len) {
    struct dirent *entry;
    DIR *dir = opendir("/sys/class/uio");
    if (!dir) return -1;

    while ((entry = readdir(dir)) != NULL) {
        if (strncmp(entry->d_name, "uio", 3) != 0) continue;

        char namepath[64];
        snprintf(namepath, sizeof(namepath), "/sys/class/uio/%s/name", entry->d_name);

        FILE *f = fopen(namepath, "r");
        if (!f) continue;

        char devname[64] = {0};
        fgets(devname, sizeof(devname), f);
        fclose(f);

        devname[strcspn(devname, "\n")] = 0;

        if (strcmp(devname, name) == 0) {
            snprintf(out_path, len, "/dev/%s", entry->d_name);
            closedir(dir);
            return 0;
        }
    }
    closedir(dir);
    return -1;
}

int main(void)
{
    char path[32];
    if (find_uio_device("encoder_axi@40000000", path, sizeof(path)) < 0) {
        fprintf(stderr, "encoder_axi UIO device not found\n");
        return 1;
    }

    int fd = open(path, O_RDWR | O_SYNC);
    if (fd < 0) { perror("Failed to open UIO device"); return 1; }

    volatile uint32_t *enc = mmap(NULL, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (enc == MAP_FAILED) { perror("Failed to mmap"); close(fd); return 1; }

    enc[0] = CTRL_CLR;
    enc[0] = CTRL_ENABLE;

    for (int i = 0; i < 30; i++)
    {
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
