const mmio = @import("./mmio.zig");
const print = @import("../lib/print.zig");

const BASE: u32 = mmio.BASE + 0x300000;
const CMDTM: *volatile Command = @ptrFromInt(BASE + 0xc);
const RESP0: *volatile u32 = @ptrFromInt(BASE + 0x10);
const RESP1: *volatile u32 = @ptrFromInt(BASE + 0x14);
const RESP2: *volatile u32 = @ptrFromInt(BASE + 0x18);
const RESP3: *volatile u32 = @ptrFromInt(BASE + 0x1c);
const STATUS: *volatile Status = @ptrFromInt(BASE + 0x24);
const CONTROL1: *volatile u32 = @ptrFromInt(BASE + 0x2c);
const INTERRUPT: *volatile u32 = @ptrFromInt(BASE + 0x30);

const Status = packed struct {
    cmd_inhibit: bool,

    dat_inhibit: bool,

    dat_active: bool,

    _padding: u5,

    write_transfer: bool,

    read_transfer: bool,

    _padding2: u10,

    dat_level0: u4,

    cmd_level: bool,

    dat_level1: u4,

    _padding3: u3,
};

const Command = packed struct {
    _padding: u1 = 0,

    tm_blkcnt_en: bool = false,

    // Used to send a CMD12 (Stop) with 0b01 or CMD23 (Idk) with 0b10 automatically
    // after a data transfer. 0b00 ignores and 0b11 is reserved.
    tm_auto_cmd_en: u2 = 0,

    // true = data transfer from card to host
    // false = data transfer from host to card
    tm_dat_dir: bool = false,

    tm_multi_block: bool = false,

    _padding2: u10 = 0,

    // 0b00 = no response
    // 0b01 = 136 bits response
    // 0b10 = 48 bits response
    // 0b11 = 48 bits response using busy
    cmd_response_type: u2 = 0b10,

    _padding3: u1 = 0,

    cmd_crchk_en: bool = false,

    cmd_ixchk_en: bool = false,

    // true if the command involves a data transfer
    cmd_isdata: bool = false,

    cmd_type: u2 = 0,

    // The command index
    // Found the list here: http://elm-chan.org/docs/mmc/mmc_e.html#spimode
    cmd_index: u6,

    _padding4: u2 = 0,
};

pub fn read() usize {
    // Not sure why but CONTROL1 & 7 needs to be 7. This has something to do with
    // the sd driver internal clock ?
    CONTROL1.* = 7;
    print.println(.{INTERRUPT.*});

    CMDTM.* = Command{
        .cmd_index = 1,
    };

    print.println(.{INTERRUPT.*});

    var resp0: u32 = RESP0.*;
    var resp1: u32 = RESP1.*;
    var resp2: u32 = RESP2.*;
    var resp3: u32 = RESP3.*;

    resp0 = RESP0.*;
    resp1 = RESP1.*;
    resp2 = RESP2.*;
    resp3 = RESP3.*;
    print.println(.{ "resp0: ", resp0, "resp1: ", resp1, "resp2: ", resp2, "resp3: ", resp3 });

    const status: Status = @bitCast(@as(u32, 0));

    print.println(.{ "cmd_inhibit: ", status.cmd_inhibit });

    print.println(.{ "dat_inhibit: ", status.dat_inhibit });

    print.println(.{ "dat_active: ", status.dat_active });

    print.println(.{ "write_transfer: ", status.write_transfer });

    print.println(.{ "read_transfer: ", status.read_transfer });

    print.println(.{ "dat_level0: ", status.dat_level0 });

    print.println(.{ "cmd_level: ", status.cmd_level });

    print.println(.{ "dat_level1: ", status.dat_level1 });

    return 0;
}
