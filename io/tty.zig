const display = @import("./display.zig");
const device = @import("./device.zig");
const print = @import("../lib/print.zig");
const pages = @import("../mem/pages.zig");

const TTYSize = struct { x: usize, y: usize, chars: usize };

pub fn get_tty_sizes() TTYSize {
    const x = display.FRAME.width / 8;
    const y = display.FRAME.height * 8;
    const chars = x * y;

    return TTYSize{ .x = x, .y = y, .chars = chars };
}

fn print_char(char: u8, x: u16, y: u16) void {
    var font = @embedFile("../assets/font.bin");
    const char_pos: u32 = @intCast(char);
    const glyph = font[8 * char_pos .. 8 * (char_pos + 1)];

    for (0..8) |i| {
        for (0..8) |j| {
            if ((glyph[i] >> @intCast(j)) & 1 != 0) {
                display.FRAME.buffer[(y + i) * display.FRAME.width + x + 7 - j].red = 0xff;
                display.FRAME.buffer[(y + i) * display.FRAME.width + x + 7 - j].green = 0xff;
                display.FRAME.buffer[(y + i) * display.FRAME.width + x + 7 - j].blue = 0xff;
            }
        }
    }
}

pub fn write_from_offset(offset: *usize, buf: [*]u8, size: usize) usize {
    var written: u32 = 0;
    var lb: u32 = offset.* / get_tty_sizes().x;
    var xi: u32 = offset.* % get_tty_sizes().x;
    for (0..size) |i| {
        if (buf[i] == '\n') {
            lb += 1;
            xi = 0;
            continue;
        }
        if (buf[i] == '\t') {
            xi += (4 - xi % 4) + 1;
            continue;
        }
        var x: u16 = @intCast((xi * 8));
        if (x + 8 > display.FRAME.width) {
            x = 0;
            xi = 0;
            lb += 1;
        }
        if ((lb + 1) * 8 > display.FRAME.height) {
            break;
        }
        print_char(buf[i], x, @intCast(lb * 8));
        xi += 1;
        written += 1;
    }

    offset.* = lb * (display.FRAME.width / 8) + xi;

    return written;
}

fn open() *device.Userinfos {
    var dev: *device.Userinfos = &pages.kmalloc(device.Userinfos, 1)[0];

    dev.offset = 0;

    return dev;
}

fn read(user_infos: *device.Userinfos, buf: [*]u8, size: usize) u32 {
    _ = user_infos;
    _ = buf;
    _ = size;

    return 0;
}

fn write(user_infos: *device.Userinfos, buf: [*]u8, size: usize) u32 {
    return write_from_offset(&user_infos.offset, buf, size);
}

fn lseek(user_infos: *device.Userinfos, offset: i32, opts: device.SEEK_OPTS) u32 {
    const base_offset: i32 = @intCast(switch (opts) {
        .SET => 0,
        .CURR => user_infos.offset,
        .END => get_tty_sizes().chars,
    });

    const new_offset: u32 = @intCast(base_offset + offset);

    user_infos.offset = @max(0, @min(get_tty_sizes().chars, new_offset));

    return user_infos.offset;
}

fn close(user_infos: *device.Userinfos) void {
    pages.kfree(@ptrCast(user_infos));
}

pub const TTY_CHAR_DEVICE = device.CharDevice{
    .open = open,
    .read = read,
    .write = write,
    .lseek = lseek,
    .close = close,
};
