const uart = @import("./mmio/uart.zig");
const syscalls = @import("./syscalls/syscalls.zig");
const exceptions = @import("./exceptions/syscalls.zig");
const print = @import("./lib/print.zig");
const mbox = @import("./mmio/mbox.zig");
const atags = @import("./mmio/atags.zig");

export fn init(r0: u32, r1: u32, r2: u32) void {
    _ = r0;
    _ = r1;

    uart.init();
    exceptions.init();
    print.debug();

    atags.init(r2);

    syscalls.init();
    mbox.init_fb();

    print.prints("Switching to user mode\n\r");
    start_user_mode();
}
export fn start_user_mode() void {
    asm volatile (
        \\ cps #16
    );
    main();
    print.prints("User mode returned\n\r");
    while (true) {}
}

fn main() void {
    print.debug();

    while (true) {
        _ = uart.read();
        syscalls.dbg(0);
        print.debug();
    }
}
