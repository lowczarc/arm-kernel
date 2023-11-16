const print = @import("../lib/print.zig");
const pages = @import("./pages.zig");

// PL0 = User mode
// Pl1 = Other modes (Supervisor)

const TTBNode = packed struct {
    // Should be 0b11 for 4KB pages, 0bx0 to ignore
    active: u2 = 0b00,

    _padding_2: u10 = 0,

    next_level_table_address: u20 = 0,

    should_be_zero_2: u8 = 0,

    should_be_zero: u12 = 0,

    _padding_1: u7 = 0,

    // true makes the subtree memory non-executable to PL1
    pxn_table: bool = false,

    // true makes the subtree memory non-executable
    xn_table: bool = false,

    // Access permission:
    // 0b00 = No effect
    // 0b01 = Subtree inaccessible to PL0
    // 0b10 = Subtree memory RO
    // 0b11 = Subtree RO and inaccessible to PL0
    ap_table: u2 = 0b00,

    // Something to do with secure state, we can ignore it
    ns_table: bool = false,
};

const TTBLeaf = packed struct {
    // Should be 0b11 for 4KB pages, 0bx0 to ignore
    active: u2 = 0b00,

    mem_attr: u4,

    hap: u2,

    // Sharability field
    sh: u2,

    // Access flag, must be true for some reason
    af: bool,

    _should_be_zero_3: u1,

    output_address: u20,

    _should_be_zero_2: u8,

    _should_be_zero_1: u12 = 0,

    upper_page_attr: u12,
};

const VAddr = packed struct {
    third: u9,
    second: u9,
    first: u2,
};

var TTBFirstLevel align(4096) = [4]TTBNode{
TTBNode{},TTBNode{},TTBNode{},TTBNode{}
};

pub fn register_addr(ph_addr: u20, addr: u20) void {
    var vaddr: VAddr = @bitCast(addr);

    if (TTBFirstLevel[vaddr.first].active != 0b11) {
        var allocated_page = pages.allocate_page().addr;
        var second_level_page: u28 = @intCast(allocated_page >> 4);
        TTBFirstLevel[vaddr.first].next_level_table_address = @intCast(second_level_page >> 8);
        TTBFirstLevel[vaddr.first].active = 0b11;
    }

    var TTBSecondLevel: [*]TTBNode = @ptrFromInt(@as(u32, TTBFirstLevel[vaddr.first].next_level_table_address) << 12);

    if (TTBSecondLevel[vaddr.second].active != 0b11) {
        var third_level_page: u28 = @intCast(pages.allocate_page().addr >> 4);
        TTBSecondLevel[vaddr.second].next_level_table_address = @intCast(third_level_page >> 8);
        TTBSecondLevel[vaddr.second].active = 0b11;
        TTBSecondLevel[vaddr.second].ap_table = 0b00;
    }

    var TTBThirdLevel: [*]TTBLeaf = @ptrFromInt(@as(u32, TTBSecondLevel[vaddr.second].next_level_table_address) << 12);

    TTBThirdLevel[vaddr.third].output_address = ph_addr;
    TTBThirdLevel[vaddr.third].af = true;
    TTBThirdLevel[vaddr.third]._should_be_zero_1 = 0;
    TTBThirdLevel[vaddr.third]._should_be_zero_2 = 0;
    TTBThirdLevel[vaddr.third]._should_be_zero_3 = 0;
    TTBThirdLevel[vaddr.third].sh = 0;
    TTBThirdLevel[vaddr.third].hap = 0;
    TTBThirdLevel[vaddr.third].mem_attr = 0;
    TTBThirdLevel[vaddr.third].upper_page_attr = 0;
    TTBThirdLevel[vaddr.third].active = 0b11;
}

const TTBR0 = packed struct {
    _padding_1: u24 = 0,
    _padding_2: u8 = 0,
    BADDR: u32,
};

const Split = packed struct {
    high: u32,
    low: u32,
};

pub fn init() void {
    var new_page = pages.allocate_page();

    var foo: *volatile u8 = @ptrFromInt(new_page.addr);
    foo.* = 42;
    register_addr(0,0);
    for (0x00000..0x3f000) |i| {
        register_addr(@intCast(i), @intCast(i));
    }

    for (0x3f000..0x40000) |i| {
        register_addr(@intCast(i), @intCast(i));
    }

    print.println(.{  @intFromPtr(&TTBFirstLevel) });

    const TTBCR = 0x80000000;
    const TTB0: Split = @bitCast(TTBR0 {
        .BADDR= @intCast(@intFromPtr(&TTBFirstLevel))
    });
    print.println(.{ "TTB0; low: ", TTB0.low, ", high: ", TTB0.high });

    asm volatile("MCRR p15, 0, r0, r1, c2"::[arg1] "{r0}" (TTB0.low), [arg2] "{r1}" (TTB0.high));
    asm volatile("MCR p15, 0, r0, c2, c0, 2"::[arg1] "{r0}" (TTBCR));

    const p_low = asm volatile("MRRC p15, 0, r0, r1, c2": [res] "={r0}" (-> usize) : [arg1] "{r1}" (0));
    const p_high = asm volatile("MRRC p15, 0, r0, r1, c2": [res] "={r1}" (-> usize) : [arg1] "{r0}" (0));


    const p_TTBCR = asm volatile("MRC p15, 0, r1, c2, c0, 2 ": [res] "={r1}" (-> usize));

    print.println(.{ "Previous TTB0; low: ", p_low, ", high: ", p_high, ", TTBCR: ", p_TTBCR });


    print.println(.{ "Activating MMU... (PC: ", asm volatile("mov r0, pc" : [ret] "={r0}" (-> usize)), ")" });
    // while (true) {}
    asm volatile(
        \\  MRC p15, 0, R1, c1, C0, 0
        \\  ORR R1, #0x1
        \\  MCR p15, 0,R1,C1, C0,0
    );
    print.println(.{ "MMU activated" });
}
