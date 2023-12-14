const syscalls = @import("./syscalls.zig");

const MallocHeader = struct {
    size: usize,
    is_free: bool,
    next: ?*MallocHeader,
    prev: ?*MallocHeader,
};

var heap: ?*MallocHeader = null;

pub fn malloc(size: u32) [*]u8 {
    const aligned_size = size + ((4 - size % 4) % 4);
    var walker: *?*MallocHeader = &heap;
    const previous: ?*MallocHeader = null;

    while (true) {
        if (walker.* == null) {
            const data_end = syscalls.brk(0);
            const new_data_end = syscalls.brk(data_end + aligned_size + @sizeOf(MallocHeader));

            walker.* = @ptrFromInt(data_end);
            walker.*.?.size = new_data_end - data_end - @sizeOf(MallocHeader);
            walker.*.?.prev = previous;
            walker.*.?.next = null;
            walker.*.?.is_free = true;
        }

        if (walker.*.?.is_free) {
            if (walker.*.?.size > aligned_size + @sizeOf(MallocHeader) + 4) {
                var next_header: *MallocHeader = @ptrFromInt(@sizeOf(MallocHeader) + aligned_size + @intFromPtr(walker.*.?));

                next_header.size = walker.*.?.size - aligned_size - @sizeOf(MallocHeader);
                next_header.is_free = true;
                next_header.next = walker.*.?.next;
                next_header.prev = walker.*.?;
                walker.*.?.next = next_header;
            }

            walker.*.?.is_free = false;

            return @ptrFromInt(@intFromPtr(walker.*.?) + @sizeOf(MallocHeader));
        }

        walker = &((walker.*.?).next);
    }
}

pub fn free(ptr: *u8) void {
    var header: *MallocHeader = @ptrFromInt(@intFromPtr(ptr) - @sizeOf(MallocHeader));

    header.is_free = true;

    if (header.prev != null and header.prev.?.is_free) {
        header.prev.?.size += @sizeOf(MallocHeader) + header.size;
        header.prev.?.next = header.next;
        header = header.prev.?;
    }

    if (header.next != null and header.next.?.is_free) {
        header.size += @sizeOf(MallocHeader) + header.next.?.size;
        header.next = header.next.?.next;
    }

    if (header.next == null) {
        const new_data_end = syscalls.brk(@intFromPtr(header));

        if (new_data_end > @intFromPtr(header) + @sizeOf(MallocHeader)) {
            header.size = new_data_end - @sizeOf(MallocHeader) - @intFromPtr(header);
        }

        if (heap == header) {
            heap = null;
        }
    }
}
