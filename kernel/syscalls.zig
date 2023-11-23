const print = @import("../lib/print.zig");
const process = @import("./process.zig");
const uart = @import("../io/uart.zig");
const fb = @import("../io/fb.zig");
const device = @import("../io/device.zig");
const tty = @import("../io/tty.zig");
const pages = @import("../mem/pages.zig");
const mmu = @import("../mem/mmu.zig");

const SYS_RESTART = 0x0;
const SYS_EXIT = 0x1;
const SYS_READ = 0x3;
const SYS_WRITE = 0x4;
const SYS_OPEN = 0x5;
const SYS_CLOSE = 0x6;
const SYS_DBG = 0x7;
const SYS_BRK = 0x2d;

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

fn str_compare(s1: [*]const u8, s2: [*]const u8) bool {
    var i: u32 = 0;
    while (s1[i] == s2[i]) : (i += 1) {
        if (s1[i] == 0) {
            return true;
        }
    }

    return false;
}

pub fn open(buf: [*]const u8) u8 {
    var char_device: *const device.CharDevice = undefined;

    if (str_compare("/dev/fb", buf)) {
        char_device = &fb.FB_CHAR_DEVICE;
    } else if (str_compare("/dev/uart", buf)) {
        char_device = &uart.UART_CHAR_DEVICE;
    } else if (str_compare("/dev/tty", buf)) {
        char_device = &tty.TTY_CHAR_DEVICE;
    } else {
        @panic("File system is not implemented yet");
    }

    return process.register_file_descriptor(process.curr_proc, char_device);
}

pub fn write(fd: u8, buf: [*]u8, size: u32) usize {
    var file_descriptor = process.curr_proc.fds[fd];

    if (file_descriptor == null) {
        print.println(.{"FileDescriptor not found"});
        @panic("File descriptor not found");
    }

    return file_descriptor.?.char_device.write(file_descriptor.?.user_infos, buf, size);
}

pub fn read(fd: u8, buf: [*]u8, size: u32) usize {
    var file_descriptor = process.curr_proc.fds[fd];

    if (file_descriptor == null) {
        print.println(.{"FileDescriptor not found"});
        @panic("File descriptor not found");
    }

    return file_descriptor.?.char_device.read(file_descriptor.?.user_infos, buf, size);
}

pub fn close(fd: u8) usize {
    var file_descriptor = process.curr_proc.fds[fd];

    if (file_descriptor == null) {
        print.println(.{"FileDescriptor not found"});
        @panic("File descriptor not found");
    }

    file_descriptor.?.char_device.close(file_descriptor.?.user_infos);

    return 0;
}

pub fn brk(data_end: usize) usize {
    if ((data_end < 0x40000000) or (data_end > 0x80000000)) {
        return 0x40000000 + process.curr_proc.data_pages * pages.PAGE_SIZE;
    }

    var new_data_pages = 1 + ((data_end - 0x40000000 - 1) / pages.PAGE_SIZE);

    if (new_data_pages > process.curr_proc.data_pages) {
        // We allocate new memory
        print.println(.{"Allocating..."});
        for (process.curr_proc.data_pages..new_data_pages) |page_nb| {
            var new_page = pages.allocate_page().addr;

            mmu.mmap_TTB_l2(process.curr_proc.TTB_l2, new_page, @intCast(page_nb), mmu.MMAP_OPTS{ .xn = false, .ap = 1 });
        }
    } else {
        // We deallocate memory
        print.println(.{"Deallocating..."});
        for (new_data_pages + 1..process.curr_proc.data_pages) |page_nb| {
            var ph_addr: u32 = @intCast(mmu.get_mmap_ph_addr_TTB_l2(process.curr_proc.TTB_l2, @intCast(page_nb)));

            ph_addr <<= 12;

            pages.free_page(pages.get_page_of(ph_addr));

            mmu.remove_mmap_TTB_l2(process.curr_proc.TTB_l2, @intCast(page_nb));
        }
    }

    process.curr_proc.data_pages = new_data_pages;

    return 0x40000000 + (pages.PAGE_SIZE * new_data_pages);
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
        SYS_OPEN => @as(usize, open(@ptrFromInt(process.curr_proc.regs.r0))),
        SYS_WRITE => write(@intCast(process.curr_proc.regs.r0), @ptrFromInt(process.curr_proc.regs.r1), process.curr_proc.regs.r2),
        SYS_READ => read(@intCast(process.curr_proc.regs.r0), @ptrFromInt(process.curr_proc.regs.r1), process.curr_proc.regs.r2),
        SYS_CLOSE => close(@intCast(process.curr_proc.regs.r0)),
        SYS_BRK => brk(process.curr_proc.regs.r0),
        else => 0x32,
    };

    process.curr_proc.regs.r0 = result;
}

const SWI: *u32 = @ptrFromInt(0x8);

pub fn init() void {
    const b_syscall_instr: u32 = ((@intFromPtr(&__syscall_handler) - 0x10) / 4) | 0xea000000;

    SWI.* = b_syscall_instr;
}
