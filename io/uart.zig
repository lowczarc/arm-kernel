const mmio = @import("./mmio.zig");
const device = @import("./device.zig");
const pages = @import("../mem/pages.zig");

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
    const c = DR.*;

    if (c == '\r') {
        return '\n';
    }
    return c;
}

fn cd_open() *device.Userinfos {
    var dev: *device.Userinfos = @ptrCast(pages.kmalloc(@sizeOf(device.Userinfos)));

    dev.offset = 0;

    return dev;
}

fn cd_read(user_infos: *device.Userinfos, buf: [*]u8, size: usize) u32 {
    _ = user_infos;
    for (0..size) |i| {
        buf[i] = read();
    }

    return size;
}

fn cd_write(user_infos: *device.Userinfos, buf: [*]u8, size: usize) u32 {
    _ = user_infos;
    for (0..size) |i| {
        write(buf[i]);
    }

    return size;
}

fn cd_lseek(user_infos: *device.Userinfos, offset: i32, opts: device.SEEK_OPTS) u32 {
    _ = user_infos;
    _ = offset;
    _ = opts;

    return 0;
}

fn cd_close(user_infos: *device.Userinfos) void {
    pages.kfree(@ptrCast(user_infos));
}

pub const UART_CHAR_DEVICE = device.CharDevice{
    .open = cd_open,
    .read = cd_read,
    .write = cd_write,
    .lseek = cd_lseek,
    .close = cd_close,
};
