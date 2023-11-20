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

var FRAME: Frame = undefined;

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

    var char_list = @embedFile("../io/fb.zig");

    var lb: u32 = 0;
    var xi: u32 = 0;
    for (0..char_list.len) |i| {
        if (char_list[i] == '\n') {
            lb += 1;
            xi = 0;
            continue;
        }
        if (char_list[i] == '\t') {
            xi += (4-xi % 4) + 1;
            continue;
        }
        var x: u16 = @intCast((xi * 8));
        if (x + 8 > WIDTH) {
            x = 0;
            xi = 0;
            lb += 1;
        }
        if ((lb + 1) * 8 > HEIGHT) {
            return;
        }
        print_char(char_list[i], x, @intCast(lb*8));
        xi += 1;

    }
}

fn print_char(char: u8, x: u16, y: u16) void {
    var font = @embedFile("../assets/font.bin");
    var char_pos: u32 = @intCast(char);
    var glyph = font[8 * char_pos .. 8 * (char_pos + 1)];

    for (0..8) |i| {
        for (0..8) |j| {
            if ((glyph[i] >> @intCast(j)) & 1 != 0) {
                FRAME.buffer[(y + i) * WIDTH + x + 7 - j].red = 0xff;
                FRAME.buffer[(y + i) * WIDTH + x + 7 - j].green = 0xff;
                FRAME.buffer[(y + i) * WIDTH + x + 7 - j].blue = 0xff;
            }
        }
    }
}
