#include "i2c_helper.h"

XIicPs IicInstance;

int IicPsInit()
{
    XIicPs_Config* Config = XIicPs_LookupConfig(XPAR_XIICPS_0_BASEADDR);
    if (Config == NULL)
        return XST_FAILURE;

    int Status = XIicPs_CfgInitialize(&IicInstance, Config, Config->BaseAddress);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    XIicPs_SetSClk(&IicInstance, 100000); // Set I2C clock to 100 kHz

    return XST_SUCCESS;
}

int IicPsScan()
{
    int Status;
    u8 SendBuffer[1] = {0};
    u16 Address;
    xil_printf("Scanning I2C bus...\n\r");

    for (Address = 1; Address < 127; Address++)
    {
        // Try to send a byte to the slave
        Status = XIicPs_MasterSendPolled(&IicInstance, SendBuffer, 1, Address);
        if (Status == XST_SUCCESS)
        {
            xil_printf("Device found at address: 0x%02X\n\r", Address);
        }
    }

    return XST_SUCCESS;
}

int IicPsTest(u16 Address)
{
    u8 SendBuffer[2] = {0x00, 0x00};
    u8 RecvBuffer[2];

    int Status = XIicPs_MasterSendPolled(&IicInstance, SendBuffer, 2, Address);
    if (Status != XST_SUCCESS)
    {
        xil_printf("I2C Write Failed\n\r");
        return Status;
    }

    Status = XIicPs_MasterRecvPolled(&IicInstance, RecvBuffer, 2, Address);
    if (Status != XST_SUCCESS)
    {
        xil_printf("I2C Read Failed\n\r");
        return Status;
    }

    xil_printf("I2C Read Data: 0x%02X 0x%02X\n\r", RecvBuffer[0], RecvBuffer[1]);
}