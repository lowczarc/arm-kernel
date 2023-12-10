const print = @import("../lib/print.zig");
const pages = @import("../mem/pages.zig");
const mmu = @import("../mem/mmu.zig");
const device = @import("../io/device.zig");

comptime {
    asm (
    // Load the registers back
        \\ __load_registers:
        \\      movw r1, #:lower16:curr_proc
        \\      movt r1, #:upper16:curr_proc
        \\      ldr r1, [r1]
        \\      ldm r1!, {r2}
        \\      msr spsr, r2

        // We need to switch to system mode to set the sp
        \\      mrs r3, cpsr
        \\      mov r2, r3
        \\      orr r3, r3, #0xf
        \\      msr cpsr, r3
        \\      ldm r1!, {sp}
        \\      msr cpsr, r2
        \\      ldm r1, {r0-r12, pc}^
    );
}

const Regs = extern struct {
    cpsr: u32 = 0,
    sp: u32 = 0,
    r0: u32 = 0,
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
    lr: u32 = 0,
};

// For now we only allow to open char device files
const FileDescriptor = struct {
    user_infos: *device.Userinfos,
    char_device: *const device.CharDevice,
};

const Process = extern struct {
    regs: Regs = Regs{},
    TTB_l2: mmu.TTBNodeTable = undefined,
    fds: [256]?*FileDescriptor = undefined,
    data_pages: u32,
    pid: u32,
    next: *Process,
};

pub export var curr_proc: *Process = undefined;

pub var pid_seq: u32 = 1;

pub fn register_file_descriptor(proc: *Process, char_device: *const device.CharDevice) u8 {
    for (0..proc.fds.len) |i| {
        if (proc.fds[i] == null) {
            var fd: *FileDescriptor = &pages.kmalloc(FileDescriptor, 1)[0];
            fd.char_device = char_device;
            fd.user_infos = fd.char_device.open();
            proc.fds[i] = fd;

            return @intCast(i);
        }
    }

    @panic("Cannot open more than 256 file descriptors for one process");
}

fn copy_process_prog_memory(proc: *Process, prog: anytype) void {
    if ((@typeInfo(@TypeOf(prog)) == .Array) and (@typeInfo(@TypeOf(prog)).Array.child == u8)) {
        var needed_pages = (prog.len + pages.PAGE_SIZE - 1) / pages.PAGE_SIZE;
        for (0..needed_pages) |page_nb| {
            var current_page = pages.kpalloc([*]u8);

            for (0..pages.PAGE_SIZE) |b| {
                if (prog.len < page_nb * pages.PAGE_SIZE + b) {
                    break;
                }

                current_page[b] = prog[page_nb * pages.PAGE_SIZE + b];
            }

            mmu.mmap_TTB_l2(proc.TTB_l2, current_page, @intCast(page_nb), mmu.MMAP_OPTS{ .xn = false, .ap = mmu.AP.RW_All });
        }
        proc.data_pages = needed_pages;
    } else {
        @compileError("Expected []u8 in prog argument in copy_process_prog_memory");
    }
}

fn new_process(prog: anytype) *Process {
    var proc: *Process = &pages.kmalloc(Process, 1)[0];

    proc.regs.lr = 0x40000000;
    proc.TTB_l2 = mmu.allocate_TTB_l2();

    copy_process_prog_memory(proc, prog);

    var stack_page = pages.get_page_of(pages.kpalloc(*anyopaque));
    mmu.mmap_TTB_l2(proc.TTB_l2, stack_page.addr, 0x3ffff, mmu.MMAP_OPTS{ .ap = mmu.AP.RW_All, .xn = false });

    proc.regs.sp = 0x7ffffffc;

    proc.regs.cpsr = asm volatile ("mrs r1, cpsr"
        : [ret] "={r1}" (-> u32),
    ) & 0xfffffff0;

    proc.next = proc;

    proc.pid = pid_seq;

    pid_seq += 1;

    return proc;
}

pub fn fork(proc: *Process) *Process {
    var new_proc: *Process = &pages.kmalloc(Process, 1)[0];

    new_proc.* = proc.*;

    proc.next = new_proc;

    new_proc.pid = pid_seq;

    new_proc.TTB_l2 = mmu.clone_TTB_l2(proc.TTB_l2);

    pid_seq += 1;

    return new_proc;
}

var context_switch_seq: u32 = 0;

pub fn context_switch(proc: *Process) noreturn {
    curr_proc = proc;

    mmu.register_l2(proc.TTB_l2, 1);

    asm volatile (
        // CONTEXTIDR
        // This is supposed to be unique per process. probably not useful for now
        // since we invalidate all the TLBs everytime anyway but it can be used to
        // keep multiple different cache of the translation table for each process
        \\ MCR p15,0,r0,c13,c0,1
        \\ dsb

        // Invalidate all TLBs
        \\ MCR p15,0,r0,c8,c7,0
        \\ MCR p15,0,r0,c8,c6,0
        \\ MCR p15,0,r0,c8,c5,0
        \\ MCR p15,0,r0,c8,c3,0

        // BPIALL (Invalidation of branching predictions)
        \\ MCR p15, 0, r0, c7, c5, 6
        \\ dsb
        \\ isb
        //
        :
        : [arg1] "{r0}" (context_switch_seq),
    );
    context_switch_seq += 1;

    asm volatile ("b __load_registers");
    unreachable;
}

pub fn start_user_mode(prog: anytype) noreturn {
    context_switch(new_process(prog));
}
