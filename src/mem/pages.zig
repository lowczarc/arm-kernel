const print = @import("../lib/print.zig");
const atags = @import("../mmio/atags.zig");

pub const Page = struct {
    addr: usize,
    allocated: bool,
    kernel: bool,
    next: ?*Page,
};

pub var all_pages: [*]Page = undefined;
pub var free_pages: ?*Page = null;

extern const __end: *usize;

fn debugPage(page: *Page) void {
    print.println(.{ "Page: ", @intFromPtr(page) });
    print.println(.{ "\taddr: ", page.addr });
    print.println(.{ "\tallocated: ", page.allocated });
    print.println(.{ "\tkernel: ", page.kernel });
}

const PAGE_SIZE_SHIFT = 12; // 1 << 12 == atags.ATAG.Core.?.PageSize;
pub const PAGE_SIZE = 1 << PAGE_SIZE_SHIFT;
pub fn init() void {
    print.prints("\n=========================\n");
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
    print.println(.{ "kernel_pages: ", kernel_pages });
    print.println(.{ "free_pages: ", @intFromPtr(free_pages) });
    print.prints("=========================\n\n");
}

const PageMallocHeader = struct {
    size: usize,
    is_free: bool,
    next: ?*PageMallocHeader,
    prev: ?*PageMallocHeader,
};

pub fn allocate_page() *Page {
    var page = free_pages.?;
    free_pages = page.next;
    page.allocated = true;
    page.next = undefined;
    var ptr: [*]u8 = @ptrFromInt(page.addr);
    for (0..PAGE_SIZE) |i| {
        ptr[i] = 0;
    }

    var header: *PageMallocHeader = @ptrFromInt(page.addr);
    header.size = PAGE_SIZE - @sizeOf(PageMallocHeader);
    header.is_free = true;
    header.next = null;
    header.prev = null;
    return page;
}

pub fn free_page(page: *Page) void {
    page.allocated = false;
    page.next = free_pages;
    free_pages = page;
}

pub fn kmalloc_in_page(page: *Page, size: usize) ?*u8 {
    var aligned_size = size + ((4 - size % 4) % 4);

    var header: *PageMallocHeader = @ptrFromInt(page.addr);
    while ((header.is_free == false) or (header.size < aligned_size)) {
        if (header.next == null) {
            return null;
        }
        header = header.next.?;
    }

    if (header.size > aligned_size + @sizeOf(PageMallocHeader)) {
        var free_part_header: *PageMallocHeader = @ptrFromInt(@intFromPtr(header) + @sizeOf(PageMallocHeader) + aligned_size);
        free_part_header.prev = header;
        free_part_header.next = header.next;
        free_part_header.is_free = true;
        free_part_header.size = header.size - aligned_size - @sizeOf(PageMallocHeader);
        header.size = aligned_size;
        header.next = free_part_header;
    }

    if ((@intFromPtr(header) + @sizeOf(PageMallocHeader) + aligned_size) > (page.addr + PAGE_SIZE)) {
        return null;
    }

    header.is_free = false;

    return @ptrFromInt(@intFromPtr(header) + @sizeOf(PageMallocHeader));
}

pub fn kfree_in_page(ptr: *u8) *PageMallocHeader {
    var header: *PageMallocHeader = @ptrFromInt(@intFromPtr(ptr) - @sizeOf(PageMallocHeader));
    header.is_free = true;
    if (header.next != null and header.next.?.is_free) {
        var next_header = header.next.?;
        header.next = next_header.next;
        header.size = header.size + @sizeOf(PageMallocHeader) + next_header.size;
    }
    if (header.prev != null and header.prev.?.is_free) {
        var prev_header = header.prev.?;
        prev_header.next = header.next;
        prev_header.size = prev_header.size + @sizeOf(PageMallocHeader) + header.size;
        header = prev_header;
    }

    return header;
}

pub fn kdbg_alloc(ptr: *u8) void {
    var header: *PageMallocHeader = @ptrFromInt(@intFromPtr(ptr) - @sizeOf(PageMallocHeader));
    print.println(.{ "Header: ", @intFromPtr(header) });
    print.println(.{ "\taddr: ", @intFromPtr(ptr) });
    print.println(.{ "\tsize: ", header.size });
    print.println(.{ "\tis_free: ", header.is_free });
    print.println(.{ "\tnext: ", @intFromPtr(header.next) });
    print.println(.{ "\tprev: ", @intFromPtr(header.prev) });
}
