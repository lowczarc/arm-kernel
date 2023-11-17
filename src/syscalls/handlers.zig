const print = @import("../lib/print.zig");
const consts = @import("./consts.zig");

comptime {
    asm (
        \\ .global
        \\ .type __syscall_handler, %function
        \\ __syscall_handler:
        \\      push {r1-r12, lr}
        \\      mrs r1, spsr
        \\      push {r1}
        \\      bl syscall_handler
        \\      pop {r1}
        \\      msr spsr, r1
        \\      ldm sp!, {r1-r12,pc}^
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
        consts.SYS_EXIT => {
            print.println(.{"Exiting..."});
            // This a QEMU specific signal
            asm volatile (
                \\ svc #0x00123456
                :
                : [arg1] "{r0}" (0x18),
                  [arg2] "{r1}" (0x20026),
            );
            return 0;
        },
        consts.SYS_DBG => {
            print.debug();
            return 0x42;
        },
        else => 0x32,
    };

    return result;
}
