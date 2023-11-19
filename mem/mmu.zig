const print = @import("../lib/print.zig");
const pages = @import("./pages.zig");

// PL0 = User mode
// Pl1 = Other modes (Supervisor)

pub const TTBNode = packed struct {
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
    ap_table: u2 = 0,

    // Something to do with secure state, we can ignore it
    ns_table: bool = false,
};

const TTBLeaf = packed struct {
    // Should be 0b11 for 4KB pages, 0bx0 to ignore
    active: u2 = 0b00,

    mem_attr: u4,

    // Access permission:
    // 0b00 = R/W by PL1 only
    // 0b01 = R/W by everyone
    // 0b10 = RO by PL1 only
    // 0b11 = RO by everyone
    ap: u2,

    // Sharability field
    sh: u2,

    // Access flag, must be true for some reason
    af: bool,

    _should_be_zero_3: u1,

    output_address: u20,

    _should_be_zero_2: u8,

    _should_be_zero_1: u12,

    contiguous_hint: bool,

    pxn: bool,

    xn: bool,

    _reserved_for_software_use: u4,

    _ignored: u5,
};

const VAddr = packed struct {
    third: u9,
    second: u9,
    first: u2,
};

var TTB_L1 align(4096) = [4]TTBNode{ TTBNode{}, TTBNode{}, TTBNode{}, TTBNode{} };

pub fn allocate_TTB_l2() [*]TTBNode {
    var TTB_node: [*]TTBNode = @ptrFromInt(pages.allocate_page().addr);

    return TTB_node;
}

const VAddrLvl2 = packed struct {
    part3: u9,
    part2: u9
};

pub const MMAP_OPTS = struct {
    // By default only accessible to kernel
    ap: u2 = 0,

    // By default non executable
    xn: bool = true,
};

pub fn mmap_TTB_l2(l2: [*]TTBNode, ph_addr: u20, addr: u18, opts: MMAP_OPTS) void {
    var vaddr: VAddrLvl2 = @bitCast(addr);

    if (l2[vaddr.part2].active != 0b11) {
        var third_level_page: u20 = @intCast(pages.allocate_page().addr >> 12);
        l2[vaddr.part2].next_level_table_address = third_level_page;
        l2[vaddr.part2].active = 0b11;
    }

    var l3: [*]TTBLeaf = @ptrFromInt(@as(u32, l2[vaddr.part2].next_level_table_address) << 12);

    l3[vaddr.part3].output_address = ph_addr;
    l3[vaddr.part3].af = true;
    l3[vaddr.part3].ap = opts.ap;
    l3[vaddr.part3].xn = opts.xn;
    l3[vaddr.part3].active = 0b11;
}

pub fn register_l2(l2: [*]TTBNode, l1_range: u2) void {
    TTB_L1[l1_range].next_level_table_address = @intCast(@intFromPtr(l2) >> 12);
    TTB_L1[l1_range].active = 0b11;
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

fn set_ttbr0(r: TTBR0) void {
    const split: Split = @bitCast(r);
    return asm volatile (
        \\ MCRR p15, 0, r0, r1, c2
        :
        : [arg1] "{r0}" (split.low),
          [arg2] "{r1}" (split.high),
    );
}

fn set_ttbcr(r: u32) void {
    return asm volatile (
        \\ MCR p15, 0, r2, c2, c0, 2
        :
        : [arg] "{r2}" (r),
    );
}

fn activate_mmu() void {
    return asm volatile (
        \\  MRC p15, 0, R1, c1, C0, 0
        \\  ORR R1, #0x1
        \\  MCR p15, 0,R1,C1, C0,0
    );
}

pub fn init() void {
    var kernel_TTB_l2 = allocate_TTB_l2();

    for (0x00000..0x3c000) |i| {
        mmap_TTB_l2(kernel_TTB_l2, @intCast(i), @intCast(i), MMAP_OPTS{ .xn= false });
    }

    // MMIO is supposed to start at 0x3f000000 but it seems the frambuffer is
    // allocated on 0x3cXXXXXX
    for (0x3c000..0x40000) |i| {
        mmap_TTB_l2(kernel_TTB_l2, @intCast(i), @intCast(i), MMAP_OPTS{});
    }

    register_l2(kernel_TTB_l2, 0);

    set_ttbcr(0x80000000);
    set_ttbr0(TTBR0{ .BADDR = @intCast(@intFromPtr(&TTB_L1)) });

    print.println(.{"Activating MMU..."});

    activate_mmu();

    print.println(.{"MMU activated"});
}
