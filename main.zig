const std = @import("std");

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    unreachable;
}

fn readFileAllocZ(path: [:0]const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = try std.fs.cwd().openFileZ(path, .{});
    defer file.close();
    const data = try allocator.alloc(u8, @intCast(try file.getEndPos()));
    errdefer allocator.free(data);
    _ = try file.readAll(data);
    return data;
}

fn Slice(comptime T: anytype) type {
    return struct {
        const Self = @This();
        const Error = error{EOF};
        left: T,
        pub fn take(self: *Self, n: anytype) Error!@TypeOf(self.left[0..n]) {
            if (self.left.len < n) return Error.EOF;
            defer self.left = self.left[n..];
            return self.left[0..n];
        }
        pub fn byte(self: *Self) Error!u8 {
            if (self.left.len < 1) return Error.EOF;
            defer self.left = self.left[1..];
            return self.left[0];
        }
        pub fn vlq(self: *Self, comptime I: type) Error!I {
            var v: I = 0;
            while ((v & 1) == 0) v = (v << 7) | (try self.byte());
            return v >> 1;
        }
    };
}

fn decryptData(buffer: []u8, xor: bool) []u8 {
    for (buffer, 2..) |*b, i|
        b.* ^= @as(u8, @truncate(i));
    if (xor) {
        for (buffer) |*b| b.* ^= 0xFF;
    }
    return buffer;
}

pub fn main() u8 {
    return xmain() catch 255;
}

/// File:
/// - iga0: [4]u8 == "IGA0"
/// - unks: [3]u32
/// - ent_len: vlq_int
/// - entries: []Entry (as [ent_len]u8)
/// - str_len: vlq_int
/// - strings: [str_len]vlq_int
/// Entry:
/// - nameoff: vlq_int
/// - offset : vlq_int
/// - length : vlq_int
fn xmain() anyerror!u8 {
    const stdout = std.io.getStdOut().writer();
    // 0. get args
    const alloc = std.heap.page_allocator;
    const argv = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, argv);
    if (argv.len < 3) {
        stdout.print("usage: program iga_file out_dir [\"xor\"]\n", .{}) catch {};
        return 1; // error.NotEnoughArgs
    }
    const xor = argv.len > 3 and std.mem.eql(u8, argv[3], "xor");

    // 1. open dir
    var dir = try std.fs.cwd().makeOpenPath(argv[2], .{});
    defer dir.close();

    // 2. load file
    const bytes = try readFileAllocZ(argv[1], alloc);
    defer alloc.free(bytes);
    var slice = Slice([]u8){ .left = bytes };

    // 3. load sections
    if (!std.mem.eql(u8, "IGA0", (try slice.take(16))[0..4])) return 2; // error.NotIGA0
    const s_entries = try slice.take(try slice.vlq(usize));
    const s_strings = try slice.take(try slice.vlq(usize));
    const s_filedat = slice.left;

    // 4. decrypt strings
    var l_strings: usize = 0;
    var s_slice = Slice([]u8){ .left = s_strings };
    for (s_strings) |*b| {
        b.* = try s_slice.vlq(u8);
        l_strings += 1;
        if (s_slice.left.len == 0) break;
    }

    // 5. read entries
    var e_slice = Slice([]u8){ .left = s_entries };
    if (e_slice.left.len > 0) {
        var prev_noff = try e_slice.vlq(usize);
        var prev_offs = try e_slice.vlq(usize);
        var prev_size = try e_slice.vlq(usize);
        while (e_slice.left.len > 0) {
            const noff = try e_slice.vlq(usize);
            const offs = try e_slice.vlq(usize);
            const size = try e_slice.vlq(usize);
            const name = s_strings[prev_noff..noff];
            const data = decryptData(s_filedat[prev_offs..][0..prev_size], xor);
            stdout.print("{s} {}\n", .{ name, data.len }) catch {};
            try dir.writeFile(name, data);
            prev_noff = noff;
            prev_offs = offs;
            prev_size = size;
        }
        const name = s_strings[prev_noff..l_strings];
        const data = decryptData(s_filedat[prev_offs..][0..prev_size], xor);
        stdout.print("{s} {}\n", .{ name, data.len }) catch {};
        try dir.writeFile(name, data);
    }

    return 0;
}
