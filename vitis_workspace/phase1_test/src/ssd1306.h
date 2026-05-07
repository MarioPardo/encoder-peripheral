#ifndef SSD1306_H
#define SSD1306_H

#include <string.h>
#include "xiicps.h"
#include "ssd1306_font.h"

#define SSD1306_ADDR   0x3C
#define SSD1306_I2C_HZ 10000

/* Send a single command byte */
static inline int ssd1306_cmd(XIicPs *iic, uint8_t cmd)
{
    uint8_t buf[2] = {0x00, cmd};
    return XIicPs_MasterSendPolled(iic, buf, 2, SSD1306_ADDR);
}

/* Send a block of pixel data (up to 128 bytes) for one page */
static inline int ssd1306_data(XIicPs *iic, uint8_t *data, int len)
{
    uint8_t buf[129];
    buf[0] = 0x40;
    memcpy(&buf[1], data, len);
    return XIicPs_MasterSendPolled(iic, buf, len + 1, SSD1306_ADDR);
}

static inline void ssd1306_init(XIicPs *iic)
{
    XIicPs_SetSClk(iic, SSD1306_I2C_HZ);

    ssd1306_cmd(iic, 0xAE);               /* display off */
    ssd1306_cmd(iic, 0x20); ssd1306_cmd(iic, 0x00); /* horizontal addressing mode */
    ssd1306_cmd(iic, 0xB0);               /* page start 0 */
    ssd1306_cmd(iic, 0xC8);               /* COM scan direction (flipped) */
    ssd1306_cmd(iic, 0x00);               /* column addr low nibble = 0 */
    ssd1306_cmd(iic, 0x10);               /* column addr high nibble = 0 */
    ssd1306_cmd(iic, 0x40);               /* display start line = 0 */
    ssd1306_cmd(iic, 0x81); ssd1306_cmd(iic, 0xFF); /* contrast max */
    ssd1306_cmd(iic, 0xA1);               /* segment remap (col 127 = SEG0) */
    ssd1306_cmd(iic, 0xA6);               /* normal display (not inverted) */
    ssd1306_cmd(iic, 0xA8); ssd1306_cmd(iic, 0x3F); /* multiplex ratio = 64 */
    ssd1306_cmd(iic, 0xA4);               /* output follows RAM content */
    ssd1306_cmd(iic, 0xD3); ssd1306_cmd(iic, 0x00); /* display offset = 0 */
    ssd1306_cmd(iic, 0xD5); ssd1306_cmd(iic, 0xF0); /* clock divide ratio */
    ssd1306_cmd(iic, 0xD9); ssd1306_cmd(iic, 0x22); /* pre-charge period */
    ssd1306_cmd(iic, 0xDA); ssd1306_cmd(iic, 0x12); /* COM pins config */
    ssd1306_cmd(iic, 0xDB); ssd1306_cmd(iic, 0x20); /* VCOMH deselect level */
    ssd1306_cmd(iic, 0x8D); ssd1306_cmd(iic, 0x14); /* charge pump enable */
    ssd1306_cmd(iic, 0xAF);               /* display on */
}

static inline void ssd1306_clear(XIicPs *iic)
{
    uint8_t blank[128];
    memset(blank, 0, sizeof(blank));
    for (int page = 0; page < 8; page++) {
        ssd1306_cmd(iic, 0xB0 | page);
        ssd1306_cmd(iic, 0x00); /* col low = 0 */
        ssd1306_cmd(iic, 0x10); /* col high = 0 */
        ssd1306_data(iic, blank, 128);
    }
}

/* Draw string at given page (0-7) and starting column (0-127) */
static inline void ssd1306_draw_string(XIicPs *iic, uint8_t col, uint8_t page,
                                        const char *str)
{
    ssd1306_cmd(iic, 0xB0 | page);
    ssd1306_cmd(iic, col & 0x0F);         /* col addr low nibble */
    ssd1306_cmd(iic, 0x10 | (col >> 4)); /* col addr high nibble */

    while (*str) {
        uint8_t c = (uint8_t)*str++;
        if (c < 0x20 || c > 0x7E) c = 0x20;
        uint8_t glyph[6];
        memcpy(glyph, font5x7[c - 0x20], 5);
        glyph[5] = 0x00; /* 1-pixel column spacer between chars */
        ssd1306_data(iic, glyph, 6);
    }
}

#endif /* SSD1306_H */
