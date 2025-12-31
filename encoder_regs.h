/*
 * This header specifies
 * 
 * 1. REGISTER ADDRESSES
 * 2. BIT  DEFINITIONS : What each bit in a register means
 * 3. FUNCTIONS to read/write registers safely
 * 
 * HOW THIS TALKS TO AXI CODE:
 * ============================
 * When software runs on the CPU and does:
 *   volatile uint32_t *ctrl_reg = (uint32_t*)(BASE_ADDR + ENCODER_CTRL);
 *   *ctrl_reg = 0x1;  // Write 1 to enable
 * 
 */

#ifndef ENCODER_REGS_H
#define ENCODER_REGS_H

#include <stdint.h>

    // Register Addresses
#define ENCODER_CTRL_OFFSET      0x00  // Control register (RW)
#define ENCODER_STATUS_OFFSET    0x04  // Status register (RO)
#define ENCODER_POSITION_OFFSET  0x08  // Position counter (RO)
#define ENCODER_VELOCITY_OFFSET  0x0C  // Velocity (RO)


    // Bit Definitions
// CTRL Register bits
#define ENCODER_CTRL_ENABLE_BIT     0
#define ENCODER_CTRL_ENABLE_MASK    (1 << ENCODER_CTRL_ENABLE_BIT)

#define ENCODER_CTRL_CLR_POS_BIT    1
#define ENCODER_CTRL_CLR_POS_MASK   (1 << ENCODER_CTRL_CLR_POS_BIT)

// STATUS Register bits
#define ENCODER_STATUS_DIRECTION_BIT  0
#define ENCODER_STATUS_DIRECTION_MASK (1 << ENCODER_STATUS_DIRECTION_BIT)

    //Register Structure
typedef struct {
    volatile uint32_t ctrl;      // Offset 0x00
    volatile uint32_t status;    // Offset 0x04
    volatile int32_t  position;  // Offset 0x08 signed
    volatile int32_t  velocity;  // Offset 0x0C signed
} encoder_regs_t;


    //Internal IO Funcitions

// Read a 32-bit register
static inline uint32_t encoder_read_reg_unsig(void *base, uint32_t offset)
{
    return *(volatile uint32_t *)((uintptr_t)base + offset);
}
// Read a signed 32-bit register
static inline int32_t encoder_read_reg_sig(void *base, uint32_t offset)
{
    return *(volatile int32_t *)((uintptr_t)base + offset);
}   

// Write a 32-bit register
static inline void encoder_write_reg(void *base, uint32_t offset, uint32_t value)
{
    *(volatile uint32_t *)((uintptr_t)base + offset) = value;
}


// High Level Functions

static inline void encoder_enable(void *base) {
    uint32_t ctrl = encoder_read_reg_unsig(base, ENCODER_CTRL_OFFSET);
    ctrl |= ENCODER_CTRL_ENABLE_MASK;  // Set enable bit
    encoder_write_reg(base, ENCODER_CTRL_OFFSET, ctrl);
}

static inline void encoder_disable(void *base) {
    uint32_t ctrl = encoder_read_reg_unsig(base, ENCODER_CTRL_OFFSET);
    ctrl &= ~ENCODER_CTRL_ENABLE_MASK;  // Clear enable bit
    encoder_write_reg(base, ENCODER_CTRL_OFFSET, ctrl);
}

static inline void encoder_clear_position(void *base) {
    uint32_t ctrl = encoder_read_reg_unsig(base, ENCODER_CTRL_OFFSET);
    ctrl |= ENCODER_CTRL_CLR_POS_MASK;  // Set clear bit (pulse)
    encoder_write_reg(base, ENCODER_CTRL_OFFSET, ctrl);
    // Note: CLR_POS is a pulse so hardware clears it
}

static inline int32_t encoder_get_position(void *base) {
    return encoder_read_reg_sig(base, ENCODER_POSITION_OFFSET);
}

static inline int32_t encoder_get_velocity(void *base) {
    return encoder_read_reg_sig(base, ENCODER_VELOCITY_OFFSET);
}

static inline uint8_t encoder_get_direction(void *base) {
    uint32_t status = encoder_read_reg_unsig(base, ENCODER_STATUS_OFFSET);
    return (status & ENCODER_STATUS_DIRECTION_MASK) ? 1 : 0;
}


#endif // ENCODER_REGS_H
