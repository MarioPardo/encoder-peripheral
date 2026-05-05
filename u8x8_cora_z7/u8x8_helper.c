#include "u8x8_helper.h"
#include "i2c_helper.h"

uint8_t u8x8_byte_i2c(u8x8_t* u8x8, uint8_t msg, uint8_t arg_int, void* arg_ptr)
{
    static uint8_t buffer[32]; /* u8g2/u8x8 will never send more than 32 bytes between START_TRANSFER and END_TRANSFER */
    static uint8_t buf_idx;
    uint8_t* data;

    switch (msg)
    {
    case U8X8_MSG_BYTE_SEND:
        data = (uint8_t*)arg_ptr;
        while (arg_int > 0)
        {
            buffer[buf_idx++] = *data;
            data++;
            arg_int--;
        }
        break;
    case U8X8_MSG_BYTE_INIT:
        /* add your custom code to init i2c subsystem */
        break;
    case U8X8_MSG_BYTE_SET_DC:
        /* ignored for i2c */
        break;
    case U8X8_MSG_BYTE_START_TRANSFER:
        buf_idx = 0;
        break;
    case U8X8_MSG_BYTE_END_TRANSFER:
        XIicPs_MasterSendPolled(&IicInstance, buffer, buf_idx, OLED_I2C_ADDRESS);
        break;
    default:
        return 0;
    }
    return 1;
}

uint8_t u8x8_gpio_and_delay(u8x8_t* u8x8, uint8_t msg, uint8_t arg_int, void* arg_ptr)
{
    switch (msg)
    {
    case U8X8_MSG_DELAY_NANO:
        usleep(arg_int == 0 ? 0 : 1);
        break;
    case U8X8_MSG_DELAY_MILLI:
        usleep(arg_int * 1000);
        break;
    case U8X8_MSG_DELAY_I2C:
        // arg_int is 1 or 4: 100KHz (5us) or 400KHz (1.25us) */
        usleep(arg_int <= 2 ? 5 : 2);
        break;
    case U8X8_MSG_GPIO_AND_DELAY_INIT:
        // no need GPIO init
        break;
    case U8X8_MSG_GPIO_RESET:
        // no GPIO reset
        break;
    case U8X8_MSG_GPIO_I2C_CLOCK: // arg_int=0: Output low at I2C clock pin
        break;                    // arg_int=1: Input dir with pullup high for I2C clock pin
    case U8X8_MSG_GPIO_I2C_DATA:  // arg_int=0: Output low at I2C data pin
        break;                    // arg_int=1: Input dir with pullup high for I2C data pin
    default:
        return 0;
    }
    return 1;
}