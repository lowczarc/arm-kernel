const syscalls = @import("./syscalls.zig");

export fn main() void {
    _ = syscalls.write("Hello world!\n", 13);
    _ = syscalls.write("Qu'est-ce qui a change ??\n", 26);
    syscalls.exit();
}
