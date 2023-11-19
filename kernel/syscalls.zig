const print = @import("../lib/print.zig");
const process = @import("./process.zig");
const uart = @import("../io/uart.zig");

const SYS_RESTART = 0;
const SYS_EXIT = 1;
const SYS_WRITE = 4;
const SYS_DBG = 7;

comptime {
    asm (
        \\ .global
        \\ .type __syscall_handler, %function
        \\ __syscall_handler:
        \\      movw sp, #:lower16:stack_top
        \\      movt sp, #:upper16:stack_top
        \\      push {r0}

        // Store the all the registers in the registers global variable
        \\      movw r0, #:lower16:curr_proc
        \\      movt r0, #:upper16:curr_proc
        \\      ldr r0, [r0]

        // cpsr, the CPSR has just been stored in SPSR by the interrupt
        \\      push {r1}
        \\      mrs r1, spsr
        \\      stm r0!, {r1}
        \\      pop {r1}

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

        // r1-12
        \\      stm r0!, {r0-r12}

        // lr
        \\      stm r0!, {lr}
        \\      pop {r0}
        \\      bl syscall_handler
        \\      b __load_registers
    );
}

pub extern fn __syscall_handler() void;

pub fn dbg() usize {
    print.debug();
    return 0x42;
}

pub fn exit() usize {
    print.println(.{"Exiting..."});
    // This a QEMU specific signal
    asm volatile (
        \\ svc #0x00123456
        :
        : [arg1] "{r0}" (0x18),
          [arg2] "{r1}" (0x20026),
    );
    return 0;
}

pub fn write(buf: [*]const u8, size: u32) usize {
    for (0..size) |i| {
        uart.write(buf[i]);
    }
    return size;
}

export fn syscall_handler(r0: u32) void {
    process.curr_proc.regs.r0 = r0;
    // The syscall number has been store previously in r7
    const num = asm volatile (""
        : [ret] "={r7}" (-> usize),
    );

    const result = switch (num) {
        SYS_RESTART => asm volatile ("b _Reset"
            : [ret] "=r" (-> usize),
        ),
        SYS_EXIT => exit(),
        SYS_DBG => dbg(),
        SYS_WRITE => write(@ptrFromInt(process.curr_proc.regs.r0), process.curr_proc.regs.r1),
        else => 0x32,
    };

    process.curr_proc.regs.r0 = result;
}

const SWI: *u32 = @ptrFromInt(0x8);

pub fn init() void {
    const b_syscall_instr: u32 = ((@intFromPtr(&__syscall_handler) - 0x10) / 4) | 0xea000000;

    SWI.* = b_syscall_instr;
}
