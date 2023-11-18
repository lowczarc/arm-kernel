const print = @import("../lib/print.zig");
const syscalls = @import("./syscalls/handlers.zig");
const pages = @import("../mem/pages.zig");

comptime {
    asm (
    // Load the registers back
        \\ __load_registers:
        \\      movw r1, #:lower16:curr_proc
        \\      movt r1, #:upper16:curr_proc
        \\      ldr r1, [r1]
        \\      ldm r1!, {r2}
        \\      msr spsr, r2
        \\      ldm r1, {r0-r12, sp, pc}^
    );
}

const Regs = extern struct {
    cpsr: u32 = 0,
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
    sp: u32 = 0,
    lr: u32 = 0,
};

const Process = extern struct {
    regs: Regs = Regs{},
    stack_page: ?*pages.Page = null,
};

var tutu = Process{};

pub export var curr_proc: *Process = undefined;

pub fn start_user_mode(main: u32) void {
    syscalls.init();

    curr_proc = @alignCast(@ptrCast(pages.kmalloc(@sizeOf(Process))));
    curr_proc.stack_page = pages.allocate_page();
    curr_proc.regs.lr = main;
    curr_proc.regs.sp = @intFromPtr(curr_proc.stack_page) + pages.PAGE_SIZE;

    curr_proc.regs.cpsr = asm volatile ("mrs r1, cpsr"
        : [ret] "={r1}" (-> u32),
    ) & 0xfffffff0;

    asm volatile ("b __load_registers");
}
