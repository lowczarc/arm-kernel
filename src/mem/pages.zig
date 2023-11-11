const print = @import("../lib/print.zig");
const atags = @import("../mmio/atags.zig");

const Page = struct {
    vaddr: usize,
    allocated: bool,
    kernel: bool,
    next: ?*Page,
};

var pages: *Page = undefined;
var free_pages: *Page = undefined;

extern const __end: *usize;

pub fn init() void {
    print.println(.{ "__end", @intFromPtr(&__end) });
}
