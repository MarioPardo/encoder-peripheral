#include "OLED.h"
#include "u8x8_helper.h"

#define U8x8_128x32
#define U8LOG_WIDTH 16

#ifdef U8x8_128x32
    class U8X8_SSD1306_128X32_NONAME_HW_I2C : public U8X8
    {
    public:
        U8X8_SSD1306_128X32_NONAME_HW_I2C() : U8X8()
        {
            u8x8_Setup(getU8x8(), u8x8_d_ssd1306_128x32_univision, u8x8_cad_ssd13xx_i2c, u8x8_byte_i2c, u8x8_gpio_and_delay);
        }
    };
    U8X8_SSD1306_128X32_NONAME_HW_I2C u8x8;
    #define U8LOG_HEIGHT 4
#else
    class U8X8_SSD1306_128X64_NONAME_HW_I2C : public U8X8
    {
    public:
        U8X8_SSD1306_128X64_NONAME_HW_I2C() : U8X8()
        {
            u8x8_Setup(getU8x8(), u8x8_d_ssd1306_128x64_noname, u8x8_cad_ssd13xx_i2c, u8x8_byte_i2c, u8x8_gpio_and_delay);
        }
    };
    U8X8_SSD1306_128X64_NONAME_HW_I2C u8x8;
    #define U8LOG_HEIGHT 8
#endif

uint8_t u8log_buffer[U8LOG_WIDTH * U8LOG_HEIGHT];
U8X8LOG u8x8log;

void setupScreen()
{
    u8x8.setI2CAddress(OLED_I2C_ADDRESS);
    u8x8.begin();
    u8x8.setFont(u8x8_font_chroma48medium8_r);
    u8x8log.begin(u8x8, U8LOG_WIDTH, U8LOG_HEIGHT, u8log_buffer);
    u8x8log.setRedrawMode(0); // 0: Update screen with newline, 1: Update screen for every char
    clearScreen();
}

void clearScreen()
{
    u8x8log.writeString("\f"); // \f = form feed: clear the screen
}
