const mmio = @import("./mmio.zig");
const print = @import("../lib/print.zig");

const BASE: u32 = mmio.BASE + 0xB880;

const MBOX_READ: *u32 = @ptrFromInt(BASE + 0x00);
const MBOX_POLL: *u32 = @ptrFromInt(BASE + 0x10);
const MBOX_SENDER: *u32 = @ptrFromInt(BASE + 0x14);
const MBOX_STATUS: *u32 = @ptrFromInt(BASE + 0x18);
const MBOX_CONFIG: *u32 = @ptrFromInt(BASE + 0x1C);
const MBOX_WRITE: *u32 = @ptrFromInt(BASE + 0x20);

const MBOX_RESPONSE: u32 = 0x80000000;
const MBOX_FULL: u32 = 0x80000000;
const MBOX_EMPTY: u32 = 0x40000000;

pub fn read(ch: u8) u32 {
    var data: u32 = 0;

    while (true) {
        var status = MBOX_STATUS.*;
        while (status & MBOX_EMPTY != 0) {
            status = MBOX_STATUS.*;
        }
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

const HEIGHT = 480;
const WIDTH = 640;

var INIT_FB_MSG: [17]u32 align(16) = [_]u32{
    68, // MSG size
    0, // Request/Response code
    0x00048003, 8, 0, WIDTH, HEIGHT, // Screen size
    0x00048004, 8, 0, WIDTH, HEIGHT, // Virtual screen size
    0x00048005, 4, 0, 24, // Bit Depth
    0, // END
};

var REQUEST_DB_MSG: [8]u32 align(16) = [_]u32{
    32, // MSG size
    0, // Request/Response code
    0x00040001, 8, 0, 16, 0, // align(16) framebuffer request
    0, // END
};

const Color = struct {
    red: u8,
    green: u8,
    blue: u8,
};

const Frame = struct {
    height: u32,
    width: u32,
    buffer: [*]Color,
};

var FRAME: Frame = undefined;

pub fn init_fb() void {
    var p: u28 = @intCast(@intFromPtr(&INIT_FB_MSG) >> 4);
    print.println(.{ "p: ", p });
    write(p, 8);

    var response = read(8);

    print.println(.{ "response init_fb: ", response, ", ", INIT_FB_MSG[1] });

    p = @intCast(@intFromPtr(&REQUEST_DB_MSG) >> 4);
    print.println(.{ "p: ", p });
    write(p, 8);

    response = read(8);

    print.println(.{ "response init_fb: ", response, ", ", REQUEST_DB_MSG[6] });

    FRAME = Frame{
        .height = HEIGHT,
        .width = WIDTH,
        .buffer = @ptrFromInt(REQUEST_DB_MSG[5])
    };

    for (0..(FRAME.width * FRAME.height)) |i| {
        FRAME.buffer[i].red = 0x10;
        FRAME.buffer[i].green = 0x10;
        FRAME.buffer[i].blue = 0x10;
    }
}
