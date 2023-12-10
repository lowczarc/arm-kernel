const syscalls = @import("./syscalls.zig");
const malloc = @import("./malloc.zig");

pub fn printx(fd: u8, x: u32) void {
    var res = malloc.malloc(11);
    res[0] = '0';
    res[1] = 'x';
    var i: u32 = 2;
    var offset: u8 = 32;
    while (offset != 0) {
        offset -= 4;
        const v: u4 = @truncate(x >> @truncate(offset));
        if (v <= 9) {
            res[i] = '0' + @as(u8, v);
        }
        if (v > 9) {
            res[i] = 'a' - 10 + @as(u8, v);
        }
        i += 1;
    }
    res[i] = '\n';

    _ = syscalls.write(fd, res, 11);
}

// This program currently needs to be embedded in the kernel binary and loaded
// to userspace memory in init.zig.
// In the future it will be loaded from the filesystem instead and this will be
// removed (or maybe moved to an example dir)
export fn main() void {
    var fd = syscalls.open("/dev/uart");

    var b = malloc.malloc(1);

    const hw = "Hello world!\n\n";
    _ = syscalls.write(fd, hw, @sizeOf(@TypeOf(hw.*)));

    var parent_pid = syscalls.get_pid();

    printx(fd, parent_pid);

    var child_pid = syscalls.fork();


    while (true) {
        if (syscalls.get_pid() == parent_pid) {
            const msg = "Hello from parent !\n\n";
            _ = syscalls.write(fd, msg, @sizeOf(@TypeOf(msg.*)));
        } else if (syscalls.get_pid() == child_pid) {
            const msg = "Hello from children !\n\n";
            _ = syscalls.write(fd, msg, @sizeOf(@TypeOf(msg.*)));
        } else {
            const msg = "Hello from WTF ???\n\n";
            _ = syscalls.write(fd, msg, @sizeOf(@TypeOf(msg.*)));
        }
        _ = syscalls.read(fd, b, 1);
        if (b[0] == 'q') {
            syscalls.exit();
        }
    }
}
