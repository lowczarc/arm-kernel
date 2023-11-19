pub const SYS_RESTART = 0;
pub const SYS_EXIT = 1;
pub const SYS_WRITE = 4;
pub const SYS_DBG = 7;

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
    _ = syscall0(SYS_RESTART);
}

pub fn dbg() usize {
    return syscall0(SYS_DBG);
}

pub fn exit() void {
    _ = syscall0(SYS_EXIT);
}

pub fn write(buf: [*]const u8, size: u32) usize {
    return syscall2(SYS_WRITE, @intFromPtr(buf), size);
}
