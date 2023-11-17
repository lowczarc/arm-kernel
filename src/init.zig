const uart = @import("./mmio/uart.zig");
const syscalls = @import("./syscalls/syscalls.zig");
const exceptions = @import("./exceptions/syscalls.zig");
const print = @import("./lib/print.zig");
const fb = @import("./mmio/fb.zig");
const atags = @import("./mmio/atags.zig");
const pages = @import("./mem/pages.zig");
const mmu = @import("./mem/mmu.zig");

export fn __aeabi_memset(s: [*]u8, c: u8, n: usize) [*]u8 {
    for (0..n) |i| {
        s[i] = c;
    }
    return s;
}

export fn __aeabi_memcpy(dest: [*]u8, src: [*]u8, n: usize) [*]u8 {
    for (0..n) |i| {
        dest[i] = src[i];
    }
    return dest;
}

export fn init(r0: u32, r1: u32, r2: u32) void {
    _ = r0;
    _ = r1;

    uart.init();
    exceptions.init();
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
    var foo: *volatile u32 = @ptrFromInt(0xfffff000);
    print.println(.{ "Reading 0xfffff000: ", foo.* });
}
