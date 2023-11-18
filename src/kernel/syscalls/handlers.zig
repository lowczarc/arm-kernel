const print = @import("../../lib/print.zig");
const consts = @import("./consts.zig");

comptime {
    asm (
        \\ .global
        \\ .type __syscall_handler, %function
        \\ __syscall_handler:
        \\      movw sp, #:lower16:stack_top
        \\      movt sp, #:upper16:stack_top
        \\      push {r0}

        // Store the all the registers in the registers global variable
        \\      movw r0, #:lower16:registers
        \\      movt r0, #:upper16:registers

        // cpsr, the CPSR has just been stored in SPSR by the interrupt
        \\      push {r1}
        \\      mrs r1, spsr
        \\      stm r0!, {r1}
        \\      pop {r1}

        // r1-12
        \\      stm r0!, {r1-r12}

        // sp, since it's banked, we need to switch to system mode to get it
        \\      push {r1,r2}
        \\      mrs r1, cpsr
        \\      mov r2, r1
        \\      orr r1, r1, #0xf
        \\      msr cpsr, r1
        \\      mov r1, sp
        \\      stm r0!, {r1}
        \\      msr cpsr, r2
        \\      pop {r1,r2}

        // lr
        \\      stm r0!, {lr}
        \\      pop {r0}
        \\      bl syscall_handler

        // Load the registers back
        \\ __load_registers:
        \\      movw r1, #:lower16:registers
        \\      movt r1, #:upper16:registers
        \\      ldm r1!, {r2}
        \\      msr spsr, r2
        \\      ldm r1, {r1-r12, sp, pc}^
    );
}

const REGISTERS = extern struct {
    cpsr: u32 = 0,
    r1: u32 = 0,
    r2: u32 = 0,
    r3: u32 = 0,
    r4: u32 = 0,
    r5: u32 = 0,
    r6: u32 = 0,
    r7: u32 = 0,
    r8: u32 = 0,
    r9: u32 = 0,
    r10: u32 = 0,
    r11: u32 = 0,
    r12: u32 = 0,
    sp: u32 = 0,
    lr: u32 = 0,
};

export var registers = REGISTERS{};

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
