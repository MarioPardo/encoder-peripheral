// SSD1306 128x64 OLED I2C test using U8g2
// Rename to .ino for Arduino IDE
// Library: U8g2 by olikraus (install via Library Manager)
// HW_I2C does NOT work with this display — must use SW_I2C

#include <Arduino.h>
#include <U8g2lib.h>

// SCL = A5, SDA = A4 on Uno/Nano — adjust if using a different board
U8G2_SSD1306_128X64_NONAME_F_SW_I2C u8g2(U8G2_R0, /* clock=*/ SCL, /* data=*/ SDA, /* reset=*/ U8X8_PIN_NONE);

void setup() {
    Serial.begin(115200);
    if (!u8g2.begin()) {
        Serial.println("Display init FAILED — check wiring and I2C address");
        while (1);
    }
    Serial.println("Display init OK");
}

void loop() {
    char buf[24];
    snprintf(buf, sizeof(buf), "t = %lu ms", millis());

    u8g2.clearBuffer();
    u8g2.setFont(u8g2_font_ncenB08_tr);
    u8g2.drawStr(0, 12, "I2C Test OK");
    u8g2.drawStr(0, 28, "SSD1306 + U8g2");
    u8g2.drawStr(0, 44, buf);
    u8g2.sendBuffer();

    delay(500);
}
