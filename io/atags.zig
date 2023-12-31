const print = @import("../lib/print.zig");

const ATAG_HEADER = extern struct {
    TagSize: u32,
    Tag: u32,
};

const ATAG_CORE = extern struct {
    Flags: u32,
    PageSize: u32,
    RootDev: u32,
};

const ATAG_MEM = extern struct {
    Size: u32,
    Start: u32,
};

const ATAG_VIDEOTEXT = extern struct {
    X: u8,
    Y: u8,
    VideoPage: u16,
    VideoMode: u8,
    VideoCols: u8,
    VideoEgaBx: u16,
    VideoLines: u8,
    VideoIsVga: u8,
    VideoPoints: u16,
};

const ATAG_RAMDISK = extern struct {
    Flags: u32,
    Size: u32,
    Start: u32,
};

const ATAG_INITRD2 = extern struct {
    Start: u32,
    Size: u32,
};

const ATAG_SERIAL = extern struct {
    Low: u32,
    High: u32,
};

const ATAG_REVISION = extern struct {
    Rev: u32,
};

const ATAG_VIDEOLFB = extern struct {
    LfbWidth: u16,
    LfbHeight: u16,
    LfbDepth: u16,
    LfbLineLength: u16,
    LfbBase: u32,
    LfbSize: u32,
    RedSize: u8,
    RedPos: u8,
    GreenSize: u8,
    GreenPos: u8,
    BlueSize: u8,
    BluePos: u8,
    RsvdSize: u8,
    RsvdPos: u8,
};

const ATAG_CMDLINE = *u8;

const ATAGS = struct {
    Core: ?*ATAG_CORE,
    Mem: ?*ATAG_MEM,
    VideoText: ?*ATAG_VIDEOTEXT,
    RamDisk: ?*ATAG_RAMDISK,
    InitRD2: ?*ATAG_INITRD2,
    Serial: ?*ATAG_SERIAL,
    Revision: ?*ATAG_REVISION,
    VideoLFB: ?*ATAG_VIDEOLFB,
    CmdLine: ?*ATAG_CMDLINE,
};

pub var ATAG: ATAGS = undefined;

pub fn init(atags: u32) void {
    var header: *ATAG_HEADER = @ptrFromInt(atags);

    while (true) {
        if (header.Tag == 0) {
            break;
        }
        switch (header.Tag) {
            0x54410001 => {
                ATAG.Core = @ptrFromInt(@intFromPtr(header) + 8);
            },
            0x54410002 => {
                ATAG.Mem = @ptrFromInt(@intFromPtr(header) + 8);
            },
            0x54410003 => {
                ATAG.VideoText = @ptrFromInt(@intFromPtr(header) + 8);
            },
            0x54410004 => {
                ATAG.RamDisk = @ptrFromInt(@intFromPtr(header) + 8);
            },
            0x54420005 => {
                ATAG.InitRD2 = @ptrFromInt(@intFromPtr(header) + 8);
            },
            0x54410006 => {
                ATAG.Serial = @ptrFromInt(@intFromPtr(header) + 8);
            },
            0x54410007 => {
                ATAG.Revision = @ptrFromInt(@intFromPtr(header) + 8);
            },
            0x54410008 => {
                ATAG.VideoLFB = @ptrFromInt(@intFromPtr(header) + 8);
            },
            0x54410009 => {
                ATAG.CmdLine = @ptrFromInt(@intFromPtr(header) + 8);
            },
            else => {
                @panic("Unknown tag");
            },
        }
        const new_header: *ATAG_HEADER = @ptrFromInt(@intFromPtr(header) + (header.TagSize * 4));
        header = new_header;
    }
}
