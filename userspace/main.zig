const syscalls = @import("./syscalls.zig");

// This program currently needs to be embedded in the kernel binary and loaded
// to userspace memory in init.zig.
// In the future it will be loaded from the filesystem instead and this will be
// removed (or maybe moved to an example dir)
export fn main() void {
    _ = syscalls.write("Hello world!\n", 13);
    syscalls.exit();
}
