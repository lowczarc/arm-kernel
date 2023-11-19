const syscalls = @import("./syscalls.zig");

export fn main() void {
    _ = syscalls.write("Hello world!\n", 13);
    syscalls.exit();
}
