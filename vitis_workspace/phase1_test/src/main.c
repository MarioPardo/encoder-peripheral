#include <stdio.h>
#include <stdint.h>
#include "xil_printf.h"
#include "xparameters.h"

#define ENC_BASE     XPAR_ENCODER_AXI_0_BASEADDR

#define REG_CTRL     *((volatile uint32_t *)(ENC_BASE + 0x00))
#define REG_STATUS   *((volatile uint32_t *)(ENC_BASE + 0x04))
#define REG_POSITION *((volatile int32_t  *)(ENC_BASE + 0x08))
#define REG_VELOCITY *((volatile int32_t  *)(ENC_BASE + 0x0C))

#define CTRL_ENABLE   (1 << 0)
#define CTRL_CLR_POS  (1 << 1)

int main(void)
{
    xil_printf("\r\n=== Phase 2: Encoder Test ===\r\n");

    REG_CTRL = CTRL_CLR_POS;
    REG_CTRL = CTRL_ENABLE;

    xil_printf("Encoder enabled. Tap BTN0/BTN1 to simulate quadrature pulses.\r\n");
    xil_printf("Polling for 30 seconds...\r\n\r\n");

    for (int i = 0; i < 150; i++) {
        int32_t pos = REG_POSITION;
        int32_t vel = REG_VELOCITY;
        uint32_t dir = REG_STATUS & 0x1;

        xil_printf("pos=%6d  vel=%6d  dir=%s\r\n",
                   pos, vel, dir ? "FWD" : "REV");

        for (volatile int d = 0; d < 2000000; d++);
    }

    REG_CTRL = 0;
    xil_printf("Done.\r\n");
    return 0;
}
