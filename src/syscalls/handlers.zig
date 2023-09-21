const print = @import("../lib/print.zig");
const consts = @import("./consts.zig");

comptime {
    asm (
        \\ .global
        \\ .type __syscall_handler, %function
        \\ __syscall_handler:
        \\      push {r0-r12, lr}
        \\      bl syscall_handler
        \\      pop {r0-r12, lr}
        \\      mrs r1, spsr
        \\      mov r2, lr
        \\      msr cpsr, r1
        \\      mov pc, r2
    );
}

pub extern fn __syscall_handler() void;

export fn syscall_handler() usize {
    // The syscall number has been store previously in r7
    const num = asm volatile (""
        : [ret] "={r7}" (-> usize),
    );

    const result = switch (num) {
        consts.SYS_RESTART => asm volatile ("b _Reset"
            : [ret] "=r" (-> usize),
        ),
        consts.SYS_DBG => {
            print.debug();
            return 0;
        },
        else => 0x32,
    };

    return result;
}
