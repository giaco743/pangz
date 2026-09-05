const std = @import("std");

const SHB_BLOCK_TYPE = [_]u8{ 0x0A, 0x0D, 0x0D, 0x0A };
const IDB_BLOCK_TYPE = [_]u8{ 0x01, 0x00, 0x00, 0x00 };
const SPB_BLOCK_TYPE = [_]u8{ 0x03, 0x00, 0x00, 0x00 };
const NRB_BLOCK_TYPE = [_]u8{ 0x04, 0x00, 0x00, 0x00 };
const ISB_BLOCK_TYPE = [_]u8{ 0x05, 0x00, 0x00, 0x00 };
const EPB_BLOCK_TYPE = [_]u8{ 0x06, 0x00, 0x00, 0x00 };
const MIN_SHB_SIZE = 28;

const Shb = struct {
    endian: std.builtin.Endian,
    block_length: u32,
    major: u16,
    minor: u16,
    section_size: i64,
    options: []const u8,

    fn init(buffer: []const u8) !Shb {
        if (buffer.len < MIN_SHB_SIZE) return error.Truncated;
        if (!std.mem.eql(u8, &SHB_BLOCK_TYPE, buffer[0..SHB_BLOCK_TYPE.len])) return error.BlockTypeMissing;

        const magic_bytes = buffer[8..12];
        const endian: std.builtin.Endian = if (std.mem.eql(
            u8,
            magic_bytes,
            &[_]u8{ 0x4D, 0x3C, 0x2B, 0x1A },
        ))
            .little
        else if (std.mem.eql(
            u8,
            magic_bytes,
            &[_]u8{ 0x1A, 0x2B, 0x3C, 0x4D },
        ))
            .big
        else
            return error.InvalidByteOrderMagic;

        const length_bytes = buffer[4..8];
        const block_length = std.mem.readInt(u32, length_bytes, endian);
        if (buffer.len < block_length) return error.Truncated;
        if ((block_length % 4) != 0) return error.MisAlligned;
        if (!std.mem.eql(u8, length_bytes, buffer[block_length - 4 .. block_length])) return error.LengthMismatch;
        const major = std.mem.readInt(u16, buffer[12..], endian);
        const minor = std.mem.readInt(u16, buffer[14..], endian);
        const section_size = std.mem.readInt(i64, buffer[16..], endian);
        const options = buffer[24 .. block_length - 4];

        return .{
            .endian = endian,
            .major = major,
            .minor = minor,
            .section_size = section_size,
            .block_length = block_length,
            .options = options,
        };
    }
    fn iterateOptions(self: *const Shb) OptionIterator {
        return .{ .buffer = self.options, .offset = 0, .endian = self.endian };
    }
};

const LinkType = enum(u16) {
    null = 0,
    ethernet = 1,
    exp_ethernet = 2,
    ax25 = 3,
    pronet = 4,
    chaos = 5,
    ieee802 = 6,
    arcnet = 7,
    slip = 8,
    ppp = 9,
    fddi = 10,
    atm_rfc1483 = 11,
    raw = 12,
    c_hdlc = 104,
    ieee802_11 = 105,
    frelay = 107,
    loop = 108,
    linux_sll = 113,
    ltalk = 114,
    pflog = 117,
    ieee802_11_radio = 127,
    linux_irda = 144,
    linux_sll2 = 276,

    _,
};

const Idb = struct {
    endian: std.builtin.Endian,
    block_length: u32,

    link_type: LinkType,
    snap_len: u32,

    options: []const u8,

    fn init(buffer: []const u8, endian: std.builtin.Endian) !Idb {
        if (buffer.len < 16) return error.TruncatedIdb;
        const block_length =
            std.mem.readInt(u32, buffer[4..8], endian);

        if (buffer.len < block_length) return error.Truncated;
        if ((block_length % 4) != 0) return error.MisAlligned;
        if (!std.mem.eql(u8, buffer[4..8], buffer[block_length - 4 .. block_length])) return error.LengthMismatch;

        const link_type: LinkType =
            @enumFromInt(std.mem.readInt(u16, buffer[8..10], endian));
        const snap_len =
            std.mem.readInt(u32, buffer[12..16], endian);
        const options = buffer[16 .. block_length - 4];
        return .{
            .endian = endian,
            .block_length = block_length,
            .link_type = link_type,
            .snap_len = snap_len,
            .options = options,
        };
    }

    fn iterateOptions(self: *const Idb) OptionIterator {
        return .{
            .buffer = self.options,
            .offset = 0,
            .endian = self.endian,
        };
    }
};

const Epb = struct {
    endian: std.builtin.Endian,
    block_length: u32,

    interface_id: u32,
    timestamp_high: u32,
    timestamp_low: u32,
    captured_length: u32,
    original_length: u32,

    packet: []const u8,
    options: []const u8,

    fn init(buffer: []const u8, endian: std.builtin.Endian) !Epb {
        if (buffer.len < 28) return error.TruncatedEpb;

        const block_length =
            std.mem.readInt(u32, buffer[4..8], endian);

        if (buffer.len < block_length) return error.Truncated;
        if ((block_length % 4) != 0) return error.MisAlligned;
        if (!std.mem.eql(
            u8,
            buffer[4..8],
            buffer[block_length - 4 .. block_length],
        )) return error.LengthMismatch;

        const interface_id =
            std.mem.readInt(u32, buffer[8..12], endian);

        const timestamp_high =
            std.mem.readInt(u32, buffer[12..16], endian);

        const timestamp_low =
            std.mem.readInt(u32, buffer[16..20], endian);

        const captured_length =
            std.mem.readInt(u32, buffer[20..24], endian);

        const original_length =
            std.mem.readInt(u32, buffer[24..28], endian);

        const packet_start = 28;

        const padded_packet_length =
            (captured_length + 3) & ~@as(u32, 3);

        const options_start =
            packet_start + padded_packet_length;

        if (options_start > block_length - 4)
            return error.InvalidPacketLength;

        const packet = buffer[packet_start .. packet_start + captured_length];

        const options = buffer[options_start .. block_length - 4];

        return .{
            .endian = endian,
            .block_length = block_length,
            .interface_id = interface_id,
            .timestamp_high = timestamp_high,
            .timestamp_low = timestamp_low,
            .captured_length = captured_length,
            .original_length = original_length,
            .packet = packet,
            .options = options,
        };
    }

    fn iterateOptions(self: *const Epb) OptionIterator {
        return .{
            .buffer = self.options,
            .offset = 0,
            .endian = self.endian,
        };
    }
};

const Option = struct {
    code: u16,
    endian: std.builtin.Endian,
    value: []const u8,

    pub fn shb(self: *const Option) !ShbOption {
        const shb_code: ShbOptionCode = @enumFromInt(self.code);

        switch (shb_code) {
            .end_of_options => {
                if (self.value.len != 0)
                    return error.InvalidOptionLength;

                return ShbOption{ .end_of_option = void };
            },

            .comment => {
                return ShbOption{ .comment = self.value };
            },

            .hardware => {
                return ShbOption{ .hardware = self.value };
            },

            .os => {
                return ShbOption{ .os = self.value };
            },

            .userappl => {
                return ShbOption{ .userappl = self.value };
            },

            _ => {
                return ShbOption{ .custom = self.value };
            },
        }
    }

    pub fn idb(self: *const Option) !IdbOption {
        const idb_code: IdbOptionCode = @enumFromInt(self.code);
        switch (idb_code) {
            .end_of_options => return IdbOption{ .end_of_option = void },
            .comment => return IdbOption{ .comment = self.value },
            .name => return IdbOption{ .name = self.value },
            .description => return IdbOption{ .comment = self.value },
            .ipv4_addr => {
                if (self.value.len != 6) return error.IpError;
                return IdbOption{ .ipv4_addr = self.value };
            },
            .ipv6_addr => {
                if (self.value.len != 17) return error.IpError;
                return IdbOption{ .ipv6_addr = self.value };
            },
            .mac_addr => {
                if (self.value.len != 6) return error.IpError;
                return IdbOption{ .mac_addr = self.value };
            },
            .eui_addr => {
                if (self.value.len != 8) return error.IpError;
                return IdbOption{ .eui_addr = self.value };
            },
            .speed => {
                if (self.value.len != 8) return error.IpError;
                const speed = std.mem.readInt(u64, self.value, self.endian);
                return IdbOption{ .speed = speed };
            },
            .tsresol => {
                if (self.value.len != 1) return error.IpError;
                const tsresol = std.mem.readInt(u8, self.value, self.endian);
                return IdbOption{ .tsresol = tsresol };
            },
            .tzone => {
                if (self.value.len != 4) return error.IpError;
                const tzone = std.mem.readInt(i32, self.value, self.endian);
                return IdbOption{ .tzone = tzone };
            },
            .filter => return IdbOption{ .filter = self.value },
            .os => return IdbOption{ .os = self.value },
            .fcslen => {
                if (self.value.len != 1) return error.IpError;
                const fcslen = std.mem.readInt(u8, self.value, self.endian);
                return IdbOption{ .fcslen = fcslen };
            },
            .tsoffset => {
                if (self.value.len != 8) return error.IpError;
                const tsoffset = std.mem.readInt(i64, self.value, self.endian);
                return IdbOption{ .tsoffset = tsoffset };
            },
            .hardware => return IdbOption{ .hardware = self.value },
            .txspeed => {
                if (self.value.len != 8) return error.IpError;
                const txspeed = std.mem.readInt(u64, self.value, self.endian);
                return IdbOption{ .txspeed = txspeed };
            },
            .rxspeed => {
                if (self.value.len != 8) return error.IpError;
                const rxspeed = std.mem.readInt(u64, self.value, self.endian);
                return IdbOption{ .rxspeed = rxspeed };
            },
            .iana_tzname => return IdbOption{ .iana_tzname = self.value },
            _ => return IdbOption{ .custom = self.value },
        }
    }

    pub fn epb(self: *const Option) !EpbOption {
        const epb_code: EpbOptionCode = @enumFromInt(self.code);

        switch (epb_code) {
            .end_of_options => {
                if (self.value.len != 0)
                    return error.InvalidOptionLength;

                return EpbOption{ .end_of_option = void };
            },

            .comment => {
                return EpbOption{ .comment = self.value };
            },

            .flags => {
                if (self.value.len != 4)
                    return error.InvalidOptionLength;

                const flags =
                    std.mem.readInt(u32, self.value, self.endian);

                return EpbOption{ .flags = flags };
            },

            .hash => {
                if (self.value.len < 1)
                    return error.InvalidOptionLength;

                return EpbOption{ .hash = self.value };
            },

            .dropcount => {
                if (self.value.len != 8)
                    return error.InvalidOptionLength;

                const dropcount =
                    std.mem.readInt(u64, self.value, self.endian);

                return EpbOption{ .dropcount = dropcount };
            },

            _ => {
                return EpbOption{ .custom = self.value };
            },
        }
    }
};

const EpbOption = union(enum) {
    end_of_option: void,
    comment: []const u8,

    flags: u32,
    hash: []const u8,
    dropcount: u64,

    custom: []const u8,
};

const EpbOptionCode = enum(u16) {
    end_of_options = 0,
    comment = 1,
    flags = 2,
    hash = 3,
    dropcount = 4,
    _,
};

const ShbOption = union(enum) {
    end_of_option: void,
    comment: []const u8,
    hardware: []const u8,
    os: []const u8,
    userappl: []const u8,
    custom: []const u8,
};

const ShbOptionCode = enum(u16) {
    end_of_options = 0,
    comment = 1,
    hardware = 2,
    os = 3,
    userappl = 4,
    _,
};

const IdbOption = union(enum) {
    end_of_option: void,
    comment: []const u8,
    name: []const u8,
    description: []const u8,

    ipv4_addr: []const u8, // 8
    ipv6_addr: []const u8, // 17

    mac_addr: []const u8, // 6
    eui_addr: []const u8, // 8

    speed: u64,
    tsresol: u8,
    tzone: i32,

    filter: []const u8,
    os: []const u8,

    fcslen: u8,
    tsoffset: i64,

    hardware: []const u8,
    txspeed: u64,
    rxspeed: u64,

    iana_tzname: []const u8,

    custom: []const u8,
};

const IdbOptionCode = enum(u16) {
    end_of_options = 0,
    comment = 1,
    name = 2,
    description = 3,
    ipv4_addr = 4,
    ipv6_addr = 5,
    mac_addr = 6,
    eui_addr = 7,
    speed = 8,
    tsresol = 9,
    tzone = 10,
    filter = 11,
    os = 12,
    fcslen = 13,
    tsoffset = 14,
    hardware = 15,
    txspeed = 16,
    rxspeed = 17,
    iana_tzname = 18,
    _,
};

const OptionIterator = struct {
    buffer: []const u8,
    offset: usize,
    endian: std.builtin.Endian,

    pub fn next(self: *OptionIterator) !?Option {
        const buffer = self.buffer[self.offset..];
        if (buffer.len < 4) return error.TruncatedOption;

        const code = std.mem.readInt(u16, buffer, self.endian);
        if (code == 0) return null;

        const length = std.mem.readInt(u16, buffer[2..], self.endian);
        const padding = (4 - (length % 4)) % 4;
        const total = 4 + length + padding;

        if (buffer.len < total)
            return error.TruncatedOption;

        self.offset += total;
        return .{
            .code = code,
            .endian = self.endian,
            .value = buffer[4..][0..length],
        };
    }
};

fn parsePcapng(buf: []const u8) !void {
    var buffer = buf;
    while (buffer.len > 0) {
        if (buffer.len < 4) return error.TruncatedMessage;
        const block_length = blk: {
            if (std.mem.eql(u8, buffer[0..4], &SHB_BLOCK_TYPE)) {
                const shb = try Shb.init(buffer);
                // ...
                break :blk shb.block_length;
            }
            if (std.mem.eql(u8, buffer[0..4], &IDB_BLOCK_TYPE)) {
                const idb = try Idb.init(buffer);
                // ...
                break :blk idb.block_length;
            }
            if (std.mem.eql(u8, buffer[0..4], &EPB_BLOCK_TYPE)) {
                const epb = try Epb.init(buffer);
                // ...
                break :blk epb.block_length;
            }
            return error.UnsupportedBlockType;
        };
        buffer = buffer[block_length..];
    }
}
