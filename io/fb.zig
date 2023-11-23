const display = @import("./display.zig");
const device = @import("./device.zig");
const pages = @import("../mem/pages.zig");

fn get_fb_size() usize {
    return display.FRAME.width * display.FRAME.height * 3;
}

fn open() *device.Userinfos {
    var dev: *device.Userinfos = &pages.kmalloc(device.Userinfos, 1)[0];

    dev.offset = 0;

    return dev;
}

fn read(user_infos: *device.Userinfos, buf: [*]u8, size: usize) u32 {
    const readable_size = @min(size, (get_fb_size() - user_infos.offset));
    var fb: [*]u8 = @ptrCast(display.FRAME.buffer);

    for (0..readable_size) |i| {
        buf[i] = fb[i + user_infos.offset];
    }

    user_infos.offset += readable_size;

    return readable_size;
}

fn write(user_infos: *device.Userinfos, buf: [*]u8, size: usize) u32 {
    const writable_size = @min(size, (get_fb_size() - user_infos.offset));
    var fb: [*]u8 = @ptrCast(display.FRAME.buffer);

    for (0..writable_size) |i| {
        fb[i + user_infos.offset] = buf[i];
    }

    user_infos.offset += writable_size;

    return writable_size;
}

fn lseek(user_infos: *device.Userinfos, offset: i32, opts: device.SEEK_OPTS) u32 {
    const base_offset: i32 = @intCast(switch (opts) {
        .SET => 0,
        .CURR => user_infos.offset,
        .END => get_fb_size(),
    });

    const new_offset: u32 = @intCast(base_offset + offset);

    user_infos.offset = @max(0, @min(get_fb_size(), new_offset));

    return user_infos.offset;
}

fn close(user_infos: *device.Userinfos) void {
    pages.kfree(@ptrCast(user_infos));
}

pub const FB_CHAR_DEVICE = device.CharDevice{
    .open = open,
    .read = read,
    .write = write,
    .lseek = lseek,
    .close = close,
};
