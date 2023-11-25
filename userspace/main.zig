const syscalls = @import("./syscalls.zig");
const malloc = @import("./malloc.zig");

// This program currently needs to be embedded in the kernel binary and loaded
// to userspace memory in init.zig.
// In the future it will be loaded from the filesystem instead and this will be
// removed (or maybe moved to an example dir)
export fn main() void {
    var fd = syscalls.open("/dev/tty");
    var fd2 = syscalls.open("/dev/uart");

    var b = malloc.malloc(1);

    _ = syscalls.write(fd, "Hello, world!\n\n", 15);
    _ = syscalls.write(fd, "Please type \"q\" to quit...\n", 27);
    while (true) {
        _ = syscalls.read(fd2, b, 1);
        if (b[0] == 'q') {
            syscalls.exit();
        }
    }
}
