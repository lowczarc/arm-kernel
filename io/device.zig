pub const Userinfos = struct {
    offset: u32,
};

pub const SEEK_OPTS = enum(u2) {
    SET = 0,
    CURR = 1,
    END = 2,
};

pub const CharDevice = struct {
    open: *const fn () *Userinfos,
    read: *const fn (user_infos: *Userinfos, buf: [*]u8, size: usize) u32,
    write: *const fn (user_infos: *Userinfos, buf: [*]u8, size: usize) u32,
    lseek: *const fn (user_infos: *Userinfos, offset: i32, opts: SEEK_OPTS) u32,
    close: *const fn (user_infos: *Userinfos) void,
};
