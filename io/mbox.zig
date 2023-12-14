const mmio = @import("./mmio.zig");

const BASE: u32 = mmio.BASE + 0xB880;

const MBOX_READ: *volatile u32 = @ptrFromInt(BASE + 0x00);
const MBOX_POLL: *volatile u32 = @ptrFromInt(BASE + 0x10);
const MBOX_SENDER: *volatile u32 = @ptrFromInt(BASE + 0x14);
const MBOX_STATUS: *volatile u32 = @ptrFromInt(BASE + 0x18);
const MBOX_CONFIG: *volatile u32 = @ptrFromInt(BASE + 0x1C);
const MBOX_WRITE: *volatile u32 = @ptrFromInt(BASE + 0x20);

const MBOX_RESPONSE: u32 = 0x80000000;
const MBOX_FULL: u32 = 0x80000000;
const MBOX_EMPTY: u32 = 0x40000000;

pub fn read(ch: u8) u32 {
    var data: u32 = 0;

    while (true) {
        while (MBOX_STATUS.* & MBOX_EMPTY != 0) {}
        data = MBOX_READ.*;
        if (data & 0xF == ch) {
            break;
        }
    }
    return data;
}

pub fn write(msg: u28, ch: u4) void {
    var status = MBOX_STATUS.*;
    while (status & MBOX_FULL != 0) {
        status = MBOX_STATUS.*;
    }
    MBOX_WRITE.* = (msg << 4) | ch;
}
