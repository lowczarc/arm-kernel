const SYS_RESTART = 0x0;
const SYS_EXIT = 0x1;
const SYS_READ = 0x3;
const SYS_WRITE = 0x4;
const SYS_OPEN = 0x5;
const SYS_CLOSE = 0x6;
const SYS_DBG = 0x7;
const SYS_BRK = 0x2d;

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

pub fn write(fd: u8, buf: [*]const u8, size: u32) usize {
    return syscall3(SYS_WRITE, @intCast(fd), @intFromPtr(buf), size);
}

pub fn read(fd: u8, buf: [*]const u8, size: u32) usize {
    return syscall3(SYS_READ, @intCast(fd), @intFromPtr(buf), size);
}

pub fn open(buf: [*]const u8) u8 {
    return @intCast(syscall1(SYS_OPEN, @intFromPtr(buf)));
}

pub fn brk(data_end: usize) usize {
    return syscall1(SYS_BRK, data_end);
}
