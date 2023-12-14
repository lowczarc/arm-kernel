const uart = @import("./io/uart.zig");
const process = @import("./kernel/process.zig");
const panic_handlers = @import("./kernel/panic.zig");
const syscalls = @import("./kernel/syscalls.zig");
const print = @import("./lib/print.zig");
const display = @import("./io/display.zig");
const atags = @import("./io/atags.zig");
const emmc = @import("./io/emmc.zig");
const pages = @import("./mem/pages.zig");
const mmu = @import("./mem/mmu.zig");
const std = @import("std");

pub fn panic(a: []const u8, b: ?*std.builtin.StackTrace, c: ?usize) noreturn {
    _ = b;
    _ = c;

    asm volatile (
        \\ mov r1, lr
        \\ b panic_handler
        :
        : [arg1] "{r0}" (4),
          [arg3] "{r2}" (&a[0]),
    );

    unreachable;
}

export fn init(r0: u32, r1: u32, r2: u32) void {
    _ = r0;
    _ = r1;

    uart.init();
    panic_handlers.init();
    atags.init(r2);
    pages.init();
    mmu.init();

    display.init();

    syscalls.init();

    print.println(.{emmc.read()});

    print.println(.{ "Switching to user mode: ", 0x40000000 });

    process.start_user_mode(@embedFile("./userspace/main.bin").*);
}
