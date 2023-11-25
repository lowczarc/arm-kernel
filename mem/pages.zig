const print = @import("../lib/print.zig");
const atags = @import("../io/atags.zig");

const PAGE_SIZE_SHIFT = 12; // 1 << 12 == atags.ATAG.Core.?.PageSize;
pub const PAGE_SIZE = 1 << PAGE_SIZE_SHIFT;

pub const Page = struct {
    addr: *align(PAGE_SIZE) allowzero anyopaque,
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

pub fn init() void {
    var num_pages = (atags.ATAG.Mem.?.Size >> PAGE_SIZE_SHIFT);
    var all_pages_size = num_pages * @sizeOf(Page);

    all_pages = @ptrCast(&__end);

    var kernel_pages = (@intFromPtr(&__end) >> PAGE_SIZE_SHIFT);
    var page_medata_size = (all_pages_size >> PAGE_SIZE_SHIFT) + 1; // we add one just to be sure

    for (0..(kernel_pages + page_medata_size)) |i| {
        var page = &all_pages[i];
        page.addr = @ptrFromInt(i << PAGE_SIZE_SHIFT);
        page.allocated = true;
        page.kernel = true;
    }

    for ((kernel_pages + page_medata_size)..num_pages) |i| {
        var page = &all_pages[i];
        page.addr = @ptrFromInt(i << PAGE_SIZE_SHIFT);
        page.allocated = false;
        page.kernel = false;
        page.next = free_pages;
        free_pages = page;
    }

}

const PageMallocHeader = struct {
    size: usize,
    is_free: bool,
    next: ?*PageMallocHeader,
    prev: ?*PageMallocHeader,
};

fn allocate_page() *Page {
    var page = free_pages.?;
    free_pages = page.next;
    page.allocated = true;
    page.next = undefined;
    var ptr: [*]u8 = @ptrCast(page.addr);
    for (0..PAGE_SIZE) |i| {
        ptr[i] = 0;
    }
    return page;
}

fn align_to_page(comptime T: type) type {
        var I = @typeInfo(T);
        if (I == .Pointer) {
            I.Pointer.alignment = PAGE_SIZE;

            return @Type(I);
        } else if (I != .Array) {
            I.Array.alignment = PAGE_SIZE;

            return @Type(I);
        } else {
            @compileError("kpalloc can only be used to allocate pointers or arrays");
        }

}

pub fn kpalloc(comptime T: type) align_to_page(T) {
    return @ptrCast(allocate_page().addr);
}

fn allocate_page_malloc_init() *align(PAGE_SIZE) PageMallocHeader {
    var header = kpalloc(*PageMallocHeader);
    header.size = PAGE_SIZE - @sizeOf(PageMallocHeader);
    header.is_free = true;
    header.next = null;
    header.prev = null;
    return header;
}

fn free_page(page: *Page) void {
    page.allocated = false;
    page.next = free_pages;
    free_pages = page;
}

pub fn get_page_of(p: anytype) *Page {
    var page_nb: u20 = undefined;

    if (@TypeOf(p) == u32 or @TypeOf(p) == usize) {
        page_nb = @intCast(p >> PAGE_SIZE_SHIFT);
    } else if (@TypeOf(p) == u20) {
        page_nb = @intCast(p);
    } else if (@typeInfo(@TypeOf(p)) != .Pointer and @typeInfo(@TypeOf(p)) != .Array) {
        page_nb = @intCast(@intFromPtr(p) >> PAGE_SIZE_SHIFT);
    }

    return &all_pages[page_nb];
}

pub fn kpfree(p: anytype) void {
    if (@typeInfo(@TypeOf(p)) != .Pointer and @typeInfo(@TypeOf(p)) != .Array) {
        @compileError("kpfree can only be used to free pointers or arrays");
    }

    free_page(get_page_of(@intFromPtr(p)));
}

pub fn kmalloc_in_page(comptime T: type, page: *align(PAGE_SIZE) PageMallocHeader, nb: usize) ?[*]align(4)T {
    var aligned_size = (nb * @sizeOf(T)) + ((4 - (nb*@sizeOf(T)) % 4) % 4);

    var header: *PageMallocHeader = page;
    while ((header.is_free == false) or (header.size < aligned_size)) {
        if (header.next == null) {
            return null;
        }
        header = header.next.?;
    }

    if (header.size > aligned_size + @sizeOf(PageMallocHeader) + 4) {
        var free_part_header: *PageMallocHeader = @ptrFromInt(@intFromPtr(header) + @sizeOf(PageMallocHeader) + aligned_size);
        free_part_header.prev = header;
        free_part_header.next = header.next;
        free_part_header.is_free = true;
        free_part_header.size = header.size - aligned_size - @sizeOf(PageMallocHeader);
        header.size = aligned_size;
        header.next = free_part_header;
    }

    if ((@intFromPtr(header) + @sizeOf(PageMallocHeader) + aligned_size) > (@intFromPtr(page) + PAGE_SIZE)) {
        return null;
    }

    header.is_free = false;

    return @ptrFromInt(@intFromPtr(header) + @sizeOf(PageMallocHeader));
}

fn same_page(a: *PageMallocHeader, b: *PageMallocHeader) bool {
    return (@intFromPtr(a) / PAGE_SIZE) == (@intFromPtr(b) / PAGE_SIZE);
}

pub fn kfree_in_page(ptr: *u8) *PageMallocHeader {
    var header: *PageMallocHeader = @ptrFromInt(@intFromPtr(ptr) - @sizeOf(PageMallocHeader));
    header.is_free = true;
    if (header.next != null and header.next.?.is_free and same_page(header, header.next.?)) {
        var next_header = header.next.?;
        header.next = next_header.next;
        header.size = header.size + @sizeOf(PageMallocHeader) + next_header.size;
    }
    if (header.prev != null and header.prev.?.is_free and same_page(header, header.prev.?)) {
        var prev_header = header.prev.?;
        prev_header.next = header.next;
        prev_header.size = prev_header.size + @sizeOf(PageMallocHeader) + header.size;
        header = prev_header;
    }

    return header;
}

var kheap: ?*align(PAGE_SIZE) PageMallocHeader = null;

pub fn kmalloc(comptime T: type, size: usize) [*]align(4) T {
    if (kheap == null) {
        kheap = allocate_page_malloc_init();
    }

    var p: ?[*]align(4) T = null;
    while (p == null) {
        p = kmalloc_in_page(T, kheap.?, size);
        if (p == null) {
            var new_kheap = allocate_page_malloc_init();
            new_kheap.next = kheap;
            kheap.?.prev = new_kheap;
            kheap = new_kheap;
        }
    }

    return p.?;
}

pub fn kfree(ptr: *u8) void {
    var header = kfree_in_page(ptr);

    if (@intFromPtr(header) % PAGE_SIZE == 0 and header.is_free == true and header.size + @sizeOf(PageMallocHeader) == PAGE_SIZE) {
        if (header.prev != null) {
            header.prev.?.next = header.next;
        }

        if (header.next != null) {
            header.next.?.prev = header.prev;
        }

        free_page(get_page_of(@intFromPtr(header)));
    }
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
