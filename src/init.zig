const uart = @import("./mmio/uart.zig");

export fn init() void {
    const msg: [*]const u8 = "Hello, world!\n\r";
    var i: u32 = 0;
    while (msg[i] != 0) {
        uart.write(msg[i]);
        i += 1;
    }
}
