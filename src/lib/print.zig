const uart = @import("../mmio/uart.zig");

pub fn prints(msg: [*]const u8) void {
    var i: u32 = 0;
    while (msg[i] != 0) {
        uart.write(msg[i]);
        i += 1;
    }
}

pub fn printx(x: u32) void {
    prints("0x");
    var offset: u8 = 32;
    while (offset != 0) {
        offset -= 4;
        const v: u4 = @truncate(x >> @truncate(offset));
        if (v <= 9) {
            uart.write('0' + @as(u8, v));
        }
        if (v > 9) {
            uart.write('a' - 10 + @as(u8, v));
        }
    }
}

pub fn printany(arg: anytype) void {
    if (@typeInfo(@TypeOf(arg)) == .Int) {
        printx(arg);
    } else if ((@typeInfo(@TypeOf(arg)) == .Array) and (@typeInfo(@TypeOf(arg)).Array.child == u8)) {
        prints(&arg);
    } else if (@typeInfo(@TypeOf(arg)) == .Pointer) {
        prints(arg);
    } else {
        prints("Unknown type: ");
        prints(@typeName(@TypeOf(arg)));
    }
}

pub fn println(args: anytype) void {
    inline for (args) |arg| {
        printany(arg);
    }
    prints("\n\r");
}

pub fn debug() void {
    const CPSR = asm volatile ("mrs %[ret], cpsr"
        : [ret] "=r" (-> usize),
    );

    const mode = CPSR & 0xf;

    const modeStr: [*]const u8 = switch (mode) {
        0 => "User",
        1 => "FIQ",
        2 => "IRQ",
        3 => "Supervisor",
        6 => "Monitor",
        7 => "Abort",
        10 => "Hypervisor",
        11 => "Undefined",
        15 => "System",
        else => "Unknown",
    };

    prints("DEBUG:\n\r");
    println(.{ "\tMode: ", modeStr, "(CPSR = ", CPSR, ")" });
}
