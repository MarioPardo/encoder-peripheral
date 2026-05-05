# I2C Display Info

**Display:** SSD1306 128x64 OLED  
**I2C Address:** 0x3C  
**I2C Clock:** Must be reduced — tested working at 10kHz and 1200Hz. Default 100kHz fails.

## Working Configurations (all confirmed)

**Adafruit SSD1306 + HW I2C (preferred — simpler API):**
```cpp
Wire.begin();
Wire.setClock(10000);
Adafruit_SSD1306 display(128, 64, &Wire, -1);
display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
```
Libraries: `Adafruit SSD1306`, `Adafruit GFX Library`

**U8g2 + HW I2C:**
```cpp
Wire.begin();
Wire.setClock(10000);
U8G2_SSD1306_128X64_NONAME_F_HW_I2C u8g2(U8G2_R0, U8X8_PIN_NONE);
u8g2.begin();
```

**U8g2 + SW I2C (fallback):**
```cpp
U8G2_SSD1306_128X64_NONAME_F_SW_I2C u8g2(U8G2_R0, SCL, SDA, U8X8_PIN_NONE);
u8g2.begin();
```

## Root Cause
The display requires a slow I2C clock. All libraries work — the original failure
with Adafruit and HW I2C was due to clock speed, not the library itself.

## Zynq Implication
Use the PS I2C controller (XIicPs). Set clock divider to achieve ~10kHz.  
No need to bit-bang via PL GPIO.
