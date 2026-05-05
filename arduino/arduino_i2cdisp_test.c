// SSD1306 128x64 OLED I2C test — Adafruit library
// Rename to .ino for Arduino IDE
// Libraries needed: Adafruit SSD1306, Adafruit GFX (install via Library Manager)
// Address: 0x3C, clock: 10000 Hz (display requires reduced speed)

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define I2C_CLOCK   10000
#define SCREEN_W    128
#define SCREEN_H    64
#define OLED_ADDR   0x3C
#define OLED_RESET  -1

Adafruit_SSD1306 display(SCREEN_W, SCREEN_H, &Wire, OLED_RESET);

void setup() {
    Serial.begin(115200);
    Wire.begin();
    Wire.setClock(I2C_CLOCK);

    if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) {
        Serial.println("Display init FAILED");
        while (1);
    }
    Serial.println("Display init OK");

    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 0);
    display.println("Adafruit Test OK");
    display.display();
}

void loop() {
    char buf[24];
    snprintf(buf, sizeof(buf), "t = %lu ms", millis());

    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("Adafruit Test OK");
    display.setCursor(0, 16);
    display.println("SSD1306 + HW I2C");
    display.setCursor(0, 32);
    display.println(buf);
    display.display();

    delay(500);
}
