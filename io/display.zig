const mbox = @import("./mbox.zig");
const print = @import("../lib/print.zig");

const HEIGHT = 1080;
const WIDTH = 1920;

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

pub var FRAME: Frame = undefined;

pub fn init() void {
    var p: u28 = @intCast(@intFromPtr(&INIT_FB_MSG) >> 4);
    mbox.write(p, 8);

    var response = mbox.read(8);

    p = @intCast(@intFromPtr(&REQUEST_DB_MSG) >> 4);
    mbox.write(p, 8);

    response = mbox.read(8);

    FRAME = Frame{ .height = HEIGHT, .width = WIDTH, .buffer = @ptrFromInt(REQUEST_DB_MSG[5]) };

    for (0..(FRAME.width * FRAME.height)) |i| {
        FRAME.buffer[i].red = 0x10;
        FRAME.buffer[i].green = 0x10;
        FRAME.buffer[i].blue = 0x10;
    }
}
