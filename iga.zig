const std = @import("std");

pub const IGAHdr = packed struct {
    sig: [4]u8,
    unk: [3][4]u8,

    pub fn checkSig(self: @This()) bool {
        return std.mem.eql(u8, &self.sig, "IGA0");
    }
};

pub const Entry64 = struct {
    filename_offset: u64,
    offset: u64,
    length: u64,
    filename: ?[]u8 = null,

    pub fn read(reader: anytype) !@This() {
        return @This(){
            .filename_offset = try mbRead(u64, reader),
            .offset = try mbRead(u64, reader),
            .length = try mbRead(u64, reader),
        };
    }
};

pub fn mbRead(comptime T: type, reader: anytype) !T {
    var v: T = 0;
    while ((v & 1) == 0)
        v = (v << 7) | (try reader.readByte());
    return v >> 1;
}

pub fn decrypt(buffer: []u8, state: *u64, xor: bool) void {
    const offset = state.*;
    for (buffer) |*b, i|
        b.* ^= @truncate(u8, offset +% i +% 2);
    if (xor)
        for (buffer) |*b| {
            b.* ^= 0xFF;
        };
    state.* = offset + buffer.len;
}
