const mmio = @import("./mmio.zig");

const BASE: u32 = mmio.BASE + 0x201000;

const DR: *u8 = @ptrFromInt(BASE + 0x00);
const FR: *u9 = @ptrFromInt(BASE + 0x18);
const LCR_H: *u8 = @ptrFromInt(BASE + 0x2C);
const CR: *u16 = @ptrFromInt(BASE + 0x30);

const LCR_H_8_BIT_MODE = 0b11 << 5;
const LCR_H_FIFO_ENABLE = 0b1 << 4;

const CR_RX_ENABLE = 0b1 << 9;
const CR_TX_ENABLE = 0b1 << 8;
const CR_UART_ENABLE = 0b1 << 0;

const FR_TX_FIFO_FULL = 0b1 << 5;
const FR_RX_FIFO_EMPTY = 0b1 << 4;

pub fn init() void {
    LCR_H.* = LCR_H_8_BIT_MODE | LCR_H_FIFO_ENABLE;

    CR.* = CR_RX_ENABLE | CR_TX_ENABLE | CR_UART_ENABLE;
}

pub fn write(c: u8) void {
    if (c == '\n') {
        write('\r');
    }
    while ((FR.* & FR_TX_FIFO_FULL) != 0) {}
    DR.* = c;
}

pub fn read() u8 {
    while ((FR.* & FR_RX_FIFO_EMPTY) != 0) {}
    return DR.*;
}
