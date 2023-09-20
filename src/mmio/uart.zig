const mmio = @import("./mmio.zig");

const UART_BASE: u32 = mmio.MMIO_BASE + 0x201000;

const UARTDR: *u8 = @ptrFromInt(UART_BASE + 0x00);

pub fn write(c: u8) void {
    UARTDR.* = c;
}
