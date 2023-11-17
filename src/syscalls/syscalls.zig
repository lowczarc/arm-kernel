const print = @import("../lib/print.zig");
const handlers = @import("./handlers.zig");
const consts = @import("./consts.zig");

const SWI: *u32 = @ptrFromInt(0x8);

pub fn init() void {
    const b_syscall_instr: u32 = ((@intFromPtr(&handlers.__syscall_handler) - 0x10) / 4) | 0xea000000;

    SWI.* = b_syscall_instr;
}

fn syscall0(number: usize) usize {
    return asm volatile ("swi 0"
        : [ret] "={r0}" (-> usize),
        : [number] "{r7}" (number),
    );
}

fn syscall1(number: usize, arg1: usize) usize {
    return asm volatile ("swi 0"
        : [ret] "={r0}" (-> usize),
        : [number] "{r7}" (number),
          [arg1] "{r0}" (arg1),
    );
}

fn syscall2(number: usize, arg1: usize, arg2: usize) usize {
    return asm volatile ("swi 0"
        : [ret] "={r0}" (-> usize),
        : [number] "{r7}" (number),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
    );
}

fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("swi 0"
        : [ret] "={r0}" (-> usize),
        : [number] "{r7}" (number),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
    );
}

pub fn restart_syscall() void {
    _ = syscall0(consts.SYS_RESTART);
}

pub fn dbg() usize {
    return syscall0(consts.SYS_DBG);
}

pub fn exit() void {
    _ = syscall0(consts.SYS_EXIT);
}
