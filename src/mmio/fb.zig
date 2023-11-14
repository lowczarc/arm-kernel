const mbox = @import("./mbox.zig");
const print = @import("../lib/print.zig");

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

pub fn init() void {
    var p: u28 = @intCast(@intFromPtr(&INIT_FB_MSG) >> 4);
    print.println(.{ "p: ", p });
    mbox.write(p, 8);

    var response = mbox.read(8);

    print.println(.{ "response init_fb: ", response, ", ", INIT_FB_MSG[1] });

    p = @intCast(@intFromPtr(&REQUEST_DB_MSG) >> 4);
    print.println(.{ "p: ", p });
    mbox.write(p, 8);

    response = mbox.read(8);

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

    print_glyph([8]u8{0x0,0x18,0x38,0x18,0x18,0x18,0x3c,0x0}, 0, 0);
    print_glyph([8]u8{0x0,0x3c,0x4e,0xe,0x3c,0x70,0x7e,0x0}, 8, 0);
    print_glyph([8]u8{0x0,0x7c,0xe,0x3c,0xe,0xe,0x7c,0x0}, 16, 0);
}

pub fn print_glyph(glyph: [8]u8, x: u16, y: u16) void {
    for (0..8) |i| {
        for (0..8) |j| {
            if ((glyph[i] >> @intCast(j)) & 1 != 0) {
                FRAME.buffer[(y+i)*WIDTH+x+7-j].red = 0xff;
                FRAME.buffer[(y+i)*WIDTH+x+7-j].green = 0xff;
                FRAME.buffer[(y+i)*WIDTH+x+7-j].blue = 0xff;
            }
        }
    }
}
