const display = @import("./display.zig");
const device = @import("./device.zig");
const print = @import("../lib/print.zig");
const pages = @import("../mem/pages.zig");

fn get_tty_size() usize {
    return (display.FRAME.width * display.FRAME.height) / (8 * 8);
}

fn print_char(char: u8, x: u16, y: u16) void {
    var font = @embedFile("../assets/font.bin");
    var char_pos: u32 = @intCast(char);
    var glyph = font[8 * char_pos .. 8 * (char_pos + 1)];

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

fn open() *device.Userinfos {
    var dev: *device.Userinfos = @ptrCast(pages.kmalloc(@sizeOf(device.Userinfos)));

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
    var written: u32 = 0;
    var lb: u32 = user_infos.offset / (display.FRAME.width / 8);
    var xi: u32 = user_infos.offset % (display.FRAME.width / 8);
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

    user_infos.offset = lb * (display.FRAME.width / 8) + xi;

    return written;
}

fn lseek(user_infos: *device.Userinfos, offset: i32, opts: device.SEEK_OPTS) u32 {
    const base_offset: i32 = @intCast(switch (opts) {
        .SET => 0,
        .CURR => user_infos.offset,
        .END => get_tty_size(),
    });

    const new_offset: u32 = @intCast(base_offset + offset);

    user_infos.offset = @max(0, @min(get_tty_size(), new_offset));

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
