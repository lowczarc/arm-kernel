const print = @import("../lib/print.zig");
const handlers = @import("./handlers.zig");

const UNDEFINED_INSTRUCTION: *u32 = @ptrFromInt(0x4);
const PREFETCH_ABORT: *u32 = @ptrFromInt(0xc);
const DATA_ABORT: *u32 = @ptrFromInt(0x10);

pub fn init() void {
    const b_undefinstr_instr: u32 = ((@intFromPtr(&handlers.__undefined_instruction_handler) - 0xc) / 4) | 0xea000000;
    UNDEFINED_INSTRUCTION.* = b_undefinstr_instr;

    const b_pabort_instr: u32 = ((@intFromPtr(&handlers.__prefetch_abort_handler) - 0x14) / 4) | 0xea000000;
    PREFETCH_ABORT.* = b_pabort_instr;

    const b_dabort_instr: u32 = ((@intFromPtr(&handlers.__data_abort_handler) - 0x18) / 4) | 0xea000000;
    DATA_ABORT.* = b_dabort_instr;
}
