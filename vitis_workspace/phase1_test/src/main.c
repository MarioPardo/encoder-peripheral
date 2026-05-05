#include <stdio.h>
#include <stdint.h>
#include "xil_printf.h"
#include "xparameters.h"
#include "xiicps.h"
#include "ssd1306.h"

#define ENC_BASE     XPAR_ENCODER_AXI_0_BASEADDR

#define REG_CTRL     *((volatile uint32_t *)(ENC_BASE + 0x00))
#define REG_STATUS   *((volatile uint32_t *)(ENC_BASE + 0x04))
#define REG_POSITION *((volatile int32_t  *)(ENC_BASE + 0x08))
#define REG_VELOCITY *((volatile int32_t  *)(ENC_BASE + 0x0C))

#define CTRL_ENABLE   (1 << 0)
#define CTRL_CLR_POS  (1 << 1)

int main(void)
{
    /* Startup delay — open serial monitor now, output follows in ~3s */
    for (volatile int d = 0; d < 100000000; d++);

    xil_printf("\r\n=== Step 2: Encoder + Display ===\r\n");

    XIicPs iic;
    XIicPs_Config *cfg = XIicPs_LookupConfig(XPAR_XIICPS_0_BASEADDR);
    XIicPs_CfgInitialize(&iic, cfg, cfg->BaseAddress);
    XIicPs_SetSClk(&iic, SSD1306_I2C_HZ);

    uint8_t test_buf[2] = {0x00, 0xAE};
    int rc = XIicPs_MasterSendPolled(&iic, test_buf, 2, SSD1306_ADDR);
    for (volatile int t = 0; t < 1000000 && XIicPs_BusIsBusy(&iic); t++);

    if (rc != XST_SUCCESS) {
        xil_printf("ERROR: No ACK from display. Check wiring Arduino SCL(P16) SDA(P15).\r\n");
        while (1);
    }

    ssd1306_init(&iic);
    ssd1306_clear(&iic);
    xil_printf("Display ready.\r\n");

    REG_CTRL = CTRL_ENABLE;
    xil_printf("Encoder enabled. Turn the knob.\r\n");

    char buf[32];
    int32_t last_pos = 0x7FFFFFFF;
    int32_t last_vel = 0x7FFFFFFF;

    while (1) {
        int32_t pos = REG_POSITION;
        int32_t vel = REG_VELOCITY;
        const char *dir = (vel > 0) ? "CW " : (vel < 0) ? "CCW" : "---";

        if (pos != last_pos) {
            snprintf(buf, sizeof(buf), "POS: %-8d", (int)pos);
            ssd1306_draw_string(&iic, 0, 0, buf);
            xil_printf("POS: %d\r\n", (int)pos);
            last_pos = pos;
        }

        if (vel != last_vel) {
            snprintf(buf, sizeof(buf), "VEL: %-8d", (int)vel);
            ssd1306_draw_string(&iic, 0, 2, buf);
            snprintf(buf, sizeof(buf), "DIR: %s", dir);
            ssd1306_draw_string(&iic, 0, 4, buf);
            xil_printf("VEL: %d  DIR: %s\r\n", (int)vel, dir);
            last_vel = vel;
        }

        for (volatile int d = 0; d < 5000000; d++); /* ~50ms poll interval */
    }

    return 0;
}
