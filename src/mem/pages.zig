const print = @import("../lib/print.zig");
const atags = @import("../mmio/atags.zig");

const Page = struct {
    addr: usize,
    allocated: bool,
    kernel: bool,
    next: ?*Page,
};

var all_pages: [*]Page = undefined;
var free_pages: ?*Page = undefined;

extern const __end: *usize;

fn debugPage(page: *Page) void {
    print.println(.{ "Page: ", @intFromPtr(page) });
    print.println(.{ "\taddr: ", page.addr });
    print.println(.{ "\tallocated", page.allocated });
    print.println(.{ "\tkernel", page.kernel });
}

const PAGE_SIZE_SHIFT = 12; // 1 << 12 == atags.ATAG.Core.?.PageSize;
const PAGE_SIZE = 1 << PAGE_SIZE_SHIFT;
pub fn init() void {
    var num_pages = (atags.ATAG.Mem.?.Size >> PAGE_SIZE_SHIFT);
    var all_pages_size = num_pages * @sizeOf(Page);
    print.println(.{ "all_pages_size: ", all_pages_size, " (Mem.Size: ", atags.ATAG.Mem.?.Size, ")" });

    all_pages = @ptrCast(&__end);

    var kernel_pages = (@intFromPtr(&__end) >> PAGE_SIZE_SHIFT);
    var page_medata_size = (all_pages_size >> PAGE_SIZE_SHIFT) + 1; // we add one just to be sure
    for (0..(kernel_pages + page_medata_size)) |i| {
        var page = &all_pages[i];
        page.addr = i << PAGE_SIZE_SHIFT;
        page.allocated = true;
        page.kernel = true;
    }
    for ((kernel_pages + page_medata_size)..num_pages) |i| {
        var page = &all_pages[i];
        page.addr = i << PAGE_SIZE_SHIFT;
        page.allocated = false;
        page.kernel = false;
        page.next = free_pages;
        free_pages = page;
    }
    print.println(.{ "__end: ", @intFromPtr(&__end) });
    print.println(.{ "kernel_pages: ", kernel_pages });
    print.println(.{ "free_pages: ", @intFromPtr(free_pages) });
}

pub fn allocate_page() *Page {
    var page = free_pages.?;
    free_pages = page.next;
    page.allocated = true;
    page.next = undefined;
    var ptr: [*]u8 = @ptrFromInt(page.addr);
    for (0..PAGE_SIZE) |i| {
        ptr[i] = 0;
    }
    return page;
}

pub fn free_page(page: *Page) void {
    page.allocated = false;
    page.next = free_pages;
    free_pages = page;
}

// type PageMallocHeader = struct {
//     size: usize,
//     is_free: bool,
//     next: ?*PageMallocHeader,
//     prev: ?*PageMallocHeader,
// };
// 
// pub fn malloc_page(page: *Page, size: usize) *u8 {
// }
