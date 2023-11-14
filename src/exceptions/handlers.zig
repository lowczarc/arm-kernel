const print = @import("../lib/print.zig");

comptime {
    asm (
        \\ .global
        \\ .type __undefined_instruction_handler, %function
        \\ __undefined_instruction_handler:
        \\      push {r0-r12, lr}
        \\      mov r0, #1
        \\      subs r1, lr, #4
        \\      bl panic_handler
        \\      pop {r0-r12, lr}
        \\      mrs r1, spsr
        \\      mov r2, lr
        \\      msr cpsr, r1
        \\      mov pc, r2
    );
}

comptime {
    asm (
        \\ .global
        \\ .type __prefetch_abort_handler, %function
        \\ __prefetch_abort_handler:
        \\      push {r0-r12, lr}
        \\      mov r0, #2
        \\      subs r1, lr, #4
        \\      bl panic_handler
        \\      pop {r0-r12, lr}
        \\      mrs r1, spsr
        \\      mov r2, lr
        \\      msr cpsr, r1
        \\      mov pc, r2
    );
}

comptime {
    asm (
        \\ .global
        \\ .type __data_abort_handler, %function
        \\ __data_abort_handler:
        \\      push {r0-r12, lr}
        \\      mov r0, #3
        \\      subs r1, lr, #4
        \\      bl panic_handler
        \\      pop {r0-r12, lr}
        \\      mrs r1, spsr
        \\      mov r2, lr
        \\      msr cpsr, r1
        \\      mov pc, r2
    );
}

pub extern fn __undefined_instruction_handler() void;
pub extern fn __prefetch_abort_handler() void;
pub extern fn __data_abort_handler() void;

export fn panic_handler(code: u32, from: u32) usize {
    // The panic number has been store previously in r7
    _ = asm volatile (""
        : [ret] "={r7}" (-> usize),
    );

    print.prints("## KERNEL PANIC ##\n");

    switch (code) {
        1 => print.prints("## Cause: Undefined instruction\n"),
        2 => print.prints("## Cause: Prefetch abort\n"),
        3 => print.prints("## Cause: Data abort\n"),
        else => print.prints("## Cause: Unknown\n"),
    }

    print.println(.{ "## From:", from });
    while (true) {}
    return 0;
}
