const syscalls = @import("./syscalls.zig");
const print = @import("../lib/print.zig");
const tty = @import("../io/tty.zig");

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

fn strlen(s: [*]u8) usize {
    var i = 0;
    while (true) {
        if (s[i] == 0) {
            return i;
        }
        i += 1;
    }
}

export fn panic_handler(code: u32, from: u32, cause: [*]u8) usize {
    print.println(.{"## KERNEL PANIC ##"});

    switch (code) {
        1 => print.prints("## Cause: Undefined instruction\n"),
        2 => print.prints("## Cause: Prefetch abort\n"),
        3 => print.prints("## Cause: Data abort\n"),
        4 => {
            print.prints("## Cause: ");
            print.prints(cause);
            print.prints("\n");
        },
        else => print.prints("## Cause: Unknown\n"),
    }

    print.println(.{ "## From:", from });

    _ = syscalls.exit();
    return 0;
}

const UNDEFINED_INSTRUCTION: *u32 = @ptrFromInt(0x4);
const PREFETCH_ABORT: *u32 = @ptrFromInt(0xc);
const DATA_ABORT: *u32 = @ptrFromInt(0x10);

pub fn init() void {
    const b_undefinstr_instr: u32 = ((@intFromPtr(&__undefined_instruction_handler) - 0xc) / 4) | 0xea000000;
    UNDEFINED_INSTRUCTION.* = b_undefinstr_instr;

    const b_pabort_instr: u32 = ((@intFromPtr(&__prefetch_abort_handler) - 0x14) / 4) | 0xea000000;
    PREFETCH_ABORT.* = b_pabort_instr;

    const b_dabort_instr: u32 = ((@intFromPtr(&__data_abort_handler) - 0x18) / 4) | 0xea000000;
    DATA_ABORT.* = b_dabort_instr;
}
