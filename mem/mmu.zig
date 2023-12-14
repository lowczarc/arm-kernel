const print = @import("../lib/print.zig");
const pages = @import("./pages.zig");

// We are using the ARMv7-A Long descriptor translation table.
// Relevant ARM Documentation:
// https://developer.arm.com/documentation/ddi0406/c/System-Level-Architecture/Virtual-Memory-System-Architecture--VMSA-/Long-descriptor-translation-table-format/Long-descriptor-translation-table-format-descriptors

const PageStatus = enum(u2) {
    Inactive = 0b00,

    // We never use block for now but it can be used for 1GB in Level 1 or 2MB in
    // level 2. It is ignored if used at level 3.
    Block = 0b01,

    // Tables give 4KB pages at level 3 only
    Page = 0b11,
};

pub const NodeAP = enum(u2) {
    NoEffect = 0b00,
    PL1 = 0b01,
    RO = 0b10,
    RO_PL1 = 0b11,
};

pub const TTBNode = packed struct {
    pageStatus: PageStatus = PageStatus.Inactive,

    _padding_1: u10 = 0,

    next_level_table_address: u20 = 0,

    _should_be_zero_1: u8 = 0,
    _should_be_zero_2: u12 = 0,
    _padding_2: u7 = 0,

    // true makes the subtree memory non-executable, PXN is for priviledge, XN for
    // everyone. A bit confusing but XN stands for "eXecute Never". I might make a
    // enum for it in the future instead of a boolean bc this is definitely the kind
    // of thing I will forget. And I don't want to change the names too much to facilitate
    // reading the ARM doc
    pxn_table: bool = false,
    xn_table: bool = false,

    ap_table: NodeAP = NodeAP.NoEffect,

    // Something to do with secure state, we can ignore it
    ns_table: bool = false,
};

pub const AP = enum(u2) {
    RW_PL1 = 0b00,
    RW_All = 0b01,
    RO_PL1 = 0b10,
    RO_All = 0b11,
};

const TTBLeaf = packed struct {
    pageStatus: PageStatus = PageStatus.Inactive,

    // I don't understand what is in this yet
    mem_attr: u4,

    ap: AP,

    // Sharability field
    // Seems to have something to do with PL2, we can probably ignore
    sh: u2,

    // Access flag, if not true we get a data access fault.
    af: bool,

    // Not global, this has an effect on translation table caching
    // Should be true for userspace memory and false for kernelspace memory
    nG: bool,

    output_address: u20,

    _should_be_zero_2: u20,

    contiguous_hint: bool,

    // Same as above. Unintuitive but true means non executable.
    pxn: bool,
    xn: bool,

    // I'll probably use this (and maybe the next 5bits if it's fine to use) to
    // reference count the memory shared between process ?
    _reserved_for_software_use: u4,
    _ignored: u5,
};

const VAddr = packed struct {
    third: u9,
    second: u9,
    first: u2,
};

var TTB_L1 align(pages.PAGE_SIZE) = [4]TTBNode{ TTBNode{}, TTBNode{}, TTBNode{}, TTBNode{} };

pub const TTBNodeTable = *align(pages.PAGE_SIZE) [512]TTBNode;
const TTBLeafTable = *align(pages.PAGE_SIZE) [512]TTBLeaf;

// We don't have a way to deallocate properly, the pages also need to be aligned
// properly and thus cannot be made with kmalloc. Will need to implement a way
// for kmalloc and kfree to manage alignment.
// Also, we should find a smart way to count the children of a Node/Leaf and
// deallocate if it is 0 without having to iterate over the 1024 children.
pub fn allocate_TTB_l2() TTBNodeTable {
    const TTB_node = pages.kpalloc(TTBNodeTable);

    return TTB_node;
}

const VAddrLvl2 = packed struct { part3: u9, part2: u9 };

pub const MMAP_OPTS = struct {
    ap: AP = AP.RW_PL1,

    // By default non executable (xn = eXecute Never)
    xn: bool = true,

    nG: bool = true,
};

fn from_phys(arg: pages.PhysAddrRange) u20 {
    return @intCast(@intFromPtr(arg) >> 12);
}

fn as_table(comptime T: type, arg: u20) pages.align_to_page(T) {
    return @ptrFromInt(@as(u32, arg) << 12);
}

pub fn mmap_TTB_l2(l2: TTBNodeTable, ph_addr: pages.PhysAddrRange, addr: u18, opts: MMAP_OPTS) void {
    const vaddr: VAddrLvl2 = @bitCast(addr);

    var l3: TTBLeafTable = undefined;
    if (l2[vaddr.part2].pageStatus != PageStatus.Page) {
        l3 = pages.kpalloc(TTBLeafTable);
        l2[vaddr.part2].next_level_table_address = from_phys(l3);
        l2[vaddr.part2].pageStatus = PageStatus.Page;
    } else {
        l3 = as_table(TTBLeafTable, l2[vaddr.part2].next_level_table_address);
    }

    l3[vaddr.part3].output_address = from_phys(ph_addr);
    l3[vaddr.part3].af = true;
    l3[vaddr.part3].ap = opts.ap;
    l3[vaddr.part3].xn = opts.xn;
    l3[vaddr.part3].nG = opts.nG;
    l3[vaddr.part3].pageStatus = PageStatus.Page;
}

pub fn get_mmap_ph_addr_TTB_l2(l2: TTBNodeTable, addr: u18) u32 {
    const vaddr: VAddrLvl2 = @bitCast(addr);

    if (l2[vaddr.part2].pageStatus != PageStatus.Page) {
        @panic("This address is not registered");
    }

    const l3 = as_table(TTBLeafTable, l2[vaddr.part2].next_level_table_address);

    return l3[vaddr.part3].output_address;
}

pub fn remove_mmap_TTB_l2(l2: TTBNodeTable, addr: u18) void {
    const vaddr: VAddrLvl2 = @bitCast(addr);

    if (l2[vaddr.part2].pageStatus != PageStatus.Page) {
        return;
    }

    var l3: TTBLeafTable = as_table(TTBLeafTable, l2[vaddr.part2].next_level_table_address);

    l3[vaddr.part3].pageStatus = PageStatus.Inactive;
}

pub fn register_l2(l2: TTBNodeTable, l1_range: u2) void {
    TTB_L1[l1_range].next_level_table_address = from_phys(l2);
    TTB_L1[l1_range].pageStatus = PageStatus.Page;
}

const TTBR0 = packed struct {
    _padding_1: u24 = 0,
    _padding_2: u8 = 0,
    BADDR: *align(4096) [4]TTBNode,
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
    const kernel_TTB_l2 = allocate_TTB_l2();

    for (0x00000..0x3c000) |i| {
        mmap_TTB_l2(kernel_TTB_l2, @ptrFromInt(i << 12), @intCast(i), MMAP_OPTS{ .xn = false, .nG = false });
    }

    // MMIO is supposed to start at 0x3f000000 but it seems the frambuffer is
    // allocated on 0x3cXXXXXX
    for (0x3c000..0x40000) |i| {
        mmap_TTB_l2(kernel_TTB_l2, @ptrFromInt(i << 12), @intCast(i), MMAP_OPTS{ .nG = false });
    }

    register_l2(kernel_TTB_l2, 0);

    set_ttbcr(0x80000000);
    set_ttbr0(TTBR0{ .BADDR = &TTB_L1 });

    print.println(.{"Activating MMU..."});

    activate_mmu();

    print.println(.{"MMU activated"});
}

pub fn clone_TTB_l2(src: TTBNodeTable) TTBNodeTable {
    const dest = allocate_TTB_l2();

    for (src, 0..) |page_l2, i| {
        const is_l2_active = page_l2.pageStatus != PageStatus.Inactive;
        if (is_l2_active) {
            const l3 = as_table(TTBLeafTable, page_l2.next_level_table_address);
            for (l3, 0..) |page_l3, j| {
                const is_l3_active = page_l3.pageStatus != PageStatus.Inactive;
                if (is_l3_active) {
                    const vaddr: u18 = @intCast((i << 9) | j);

                    const old_page = pages.get_page_of(page_l3.output_address);

                    const new_page = pages.clone_page(old_page);

                    mmap_TTB_l2(dest, new_page.addr, vaddr, MMAP_OPTS{ .xn = page_l3.xn, .ap = page_l3.ap });
                }
            }
        }
    }

    return dest;
}
