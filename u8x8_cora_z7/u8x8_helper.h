#ifndef _u8x8_helper_h
#define _u8x8_helper_h

#include "xparameters.h"
#include "sleep.h"
#include "u8g2.h"

#ifdef __cplusplus
extern "C" {
#endif

#define OLED_I2C_ADDRESS 0x3C // Your I2C device address

uint8_t u8x8_byte_i2c(u8x8_t* u8x8, uint8_t msg, uint8_t arg_int, void* arg_ptr);   //ver 2
uint8_t u8x8_gpio_and_delay(u8x8_t* u8x8, uint8_t msg, uint8_t arg_int, void* arg_ptr);

#ifdef __cplusplus
}
#endif

#endif //_u8x8_helper_h