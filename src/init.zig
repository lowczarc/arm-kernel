const uart = @import("./mmio/uart.zig");
const syscalls = @import("./syscalls/syscalls.zig");
const print = @import("./lib/print.zig");

export fn init() void {
    uart.init();
    syscalls.init();
    print.debug();

    print.prints("Switching to user mode\n\r");
    start_user_mode();
}

fn start_user_mode() void {
    asm volatile (
        \\ cps #16
        \\ ldr sp, =user_stack_top
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
