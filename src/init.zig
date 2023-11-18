const uart = @import("./io/uart.zig");
const syscalls = @import("./kernel/syscalls/syscalls.zig");
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

    syscalls.init();

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
    print.debug();
    _ = syscalls.dbg();
    print.debug();
    var foo: *volatile u32 = @ptrFromInt(0xfffff000);
    print.println(.{ "Reading 0xfffff000: ", foo.* });
}
