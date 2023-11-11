const uart = @import("./mmio/uart.zig");
const syscalls = @import("./syscalls/syscalls.zig");
const exceptions = @import("./exceptions/syscalls.zig");
const print = @import("./lib/print.zig");
const mbox = @import("./mmio/mbox.zig");
const atags = @import("./mmio/atags.zig");
const pages = @import("./mem/pages.zig");

export fn init(r0: u32, r1: u32, r2: u32) void {
    _ = r0;
    _ = r1;

    uart.init();
    exceptions.init();
    atags.init(r2);

    pages.init();

    syscalls.init();

    print.debug();
    print.println(.{"Switching to user mode"});
    start_user_mode();
}
export fn start_user_mode() void {
    asm volatile (
        \\ cps #16
    );
    main();
    print.println(.{"User mode returned"});
    syscalls.exit();
}

fn main() void {
    print.println(.{"Debug user mode:"});
    print.debug();

    print.println(.{"Syscall debug:"});
    syscalls.dbg();
}
