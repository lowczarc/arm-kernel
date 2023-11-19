const print = @import("../lib/print.zig");
const pages = @import("../mem/pages.zig");
const mmu = @import("../mem/mmu.zig");

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

const Process = extern struct {
    regs: Regs = Regs{},
    stack_page: ?*pages.Page = null,
    TTB_l2: [*]mmu.TTBNode = undefined,
};

pub export var curr_proc: *Process = undefined;

fn copy_process_prog_memory(proc: *Process, prog: anytype) void {
    if ((@typeInfo(@TypeOf(prog)) == .Array) and (@typeInfo(@TypeOf(prog)).Array.child == u8)) {
        for (0..(prog.len + pages.PAGE_SIZE - 1) / pages.PAGE_SIZE) |page_nb| {
            var current_page: [*]u8 = @ptrFromInt(pages.allocate_page().addr);

            for (0..pages.PAGE_SIZE) |b| {
                if (prog.len < page_nb * pages.PAGE_SIZE + b) {
                    break;
                }

                current_page[b] = prog[page_nb * pages.PAGE_SIZE + b];
            }

            mmu.mmap_TTB_l2(
                proc.TTB_l2,
                @intCast(@intFromPtr(current_page) >> 12),
                @intCast(page_nb),
                mmu.MMAP_OPTS{ .xn = false, .ap = 1 }
            );
        }
    } else {
        @compileError("Expected []u8 in prog argument in copy_process_prog_memory");
    }
}

fn new_process(prog: anytype) *Process {
    var proc: *Process = @alignCast(@ptrCast(pages.kmalloc(@sizeOf(Process))));

    proc.regs.lr = 0x40000000;
    proc.TTB_l2 = mmu.allocate_TTB_l2();

    copy_process_prog_memory(proc, prog);

    proc.stack_page = pages.allocate_page();
    mmu.mmap_TTB_l2(
        proc.TTB_l2,
        @intCast(proc.stack_page.?.addr >> 12), 0x3ffff,
        mmu.MMAP_OPTS{ .ap = 1, .xn = false
    });

    proc.regs.sp = 0x7ffffffc;

    proc.regs.cpsr = asm volatile ("mrs r1, cpsr"
        : [ret] "={r1}" (-> u32),
    ) & 0xfffffff0;

    return proc;
}

fn context_switch(proc: *Process) noreturn {
    curr_proc = proc;
    mmu.register_l2(proc.TTB_l2, 1);

    asm volatile ("b __load_registers");
    unreachable;
}

pub fn start_user_mode(prog: anytype) noreturn {
    context_switch(new_process(prog));
}