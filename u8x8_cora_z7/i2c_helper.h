#ifndef _i2c_helper_h
#define _i2c_helper_h

#include "xparameters.h"
#include "xiicps.h"

#ifdef __cplusplus
extern "C" {
#endif

extern XIicPs IicInstance;

int IicPsInit();
int IicPsScan();
int IicPsTest(u16 Address);

#ifdef __cplusplus
}
#endif

#endif //_i2c_helper_h