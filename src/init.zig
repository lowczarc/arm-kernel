const uart = @import("./io/uart.zig");
const process = @import("./kernel/process.zig");
const panic = @import("./kernel/panic.zig");
const print = @import("./lib/print.zig");
const fb = @import("./io/fb.zig");
const atags = @import("./io/atags.zig");
const pages = @import("./mem/pages.zig");
const mmu = @import("./mem/mmu.zig");

export fn init(r0: u32, r1: u32, r2: u32) void {
    _ = r0;
    _ = r1;

    uart.init();
    panic.init();
    atags.init(r2);

    pages.init();

    mmu.init();

    fb.init();

    var file align(32) = @embedFile("./main.bin").*;
    var userspace_main: [*]u8 = @ptrFromInt(pages.allocate_page().addr);

    @memcpy(userspace_main, &file);

    mmu.register_addr(@intCast(@intFromPtr(userspace_main) >> 12), 0x80000, 1);

    print.println(.{"Switching to user mode: ", 0x80000000});
    process.start_user_mode(0x80000000);
}
