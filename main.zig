const std = @import("std");
const prot = std.posix.PROT.READ | std.posix.PROT.WRITE;
const Slic = struct {
    const Self = @This();
    left: []u8,
    pub fn take(self: *Self, n: anytype) !@TypeOf(self.left[0..n]) {
        if (self.left.len < n) return error.EOF;
        defer self.left = self.left[n..];
        return self.left[0..n];
    }
    pub fn vlq(self: *Self, comptime I: type) !I {
        var v: I = 0;
        while ((v & 1) == 0) v = (v << 7) | (try self.take(1))[0];
        return v >> 1;
    }
};
fn decrypt(buf: []u8, xor: bool) []u8 {
    for (buf, 2..) |*b, i|
        b.* ^= @as(u8, @truncate(i));
    if (xor) {
        for (buf) |*b| b.* ^= 0xFF;
    }
    return buf;
}
pub fn main() u8 {
    realMain() catch |e| {
        std.debug.print("{s}\n", .{switch (e) {
            error.EOF => "eof error",
            error.Usage => "usage: ziga igafile [outdir(empty for listing)]",
            error.SysErr => "syscall error",
            error.NotIGA0 => "not an iga",
        }});
        return 255;
    };
    return 0;
}
fn sysErr(e: anytype) error{SysErr}!@TypeOf(e catch unreachable) {
    return e catch return error.SysErr;
}
fn realMain() !void {
    // 0. get arg, open file
    var argv = std.process.args();
    _ = argv.skip(); // skip self
    const fd = try sysErr(std.posix.openZ(argv.next() orelse return error.Usage, .{}, 0));
    const map = try sysErr(std.posix.mmap(null, @intCast((try sysErr(std.posix.fstat(fd))).size),
                                          prot, .{ .TYPE = .PRIVATE }, fd, 0));
    const dir = if (argv.next()) |path| try sysErr(std.fs.cwd().makeOpenPath(path, .{})) else null;
    var slice = Slic{ .left = map };
    if (!std.mem.eql(u8, "IGA0", (try slice.take(16))[0..4])) return error.NotIGA0;
    const s_ent = try slice.take(try slice.vlq(usize));
    const s_str = try slice.take(try slice.vlq(usize));
    const names = names: {
        var l: usize = 0;
        var s = Slic{ .left = s_str };
        while (s.vlq(u8)) |c| : (l += 1) s_str[l] = c else |_| break :names s_str[0..l];
    };
    var s_info = Slic{ .left = s_ent };
    var prev_n = s_info.vlq(usize) catch return;
    while (s_info.vlq(usize)) |offs| {
        const size = try s_info.vlq(usize);
        const nend = s_info.vlq(usize) catch names.len;
        const name = names[prev_n..nend];
        prev_n = nend;
        std.debug.print("{s} {}\n", .{ name, size });
        if (dir) |d| try sysErr(d.writeFile(.{
            .sub_path = name,
            .data = decrypt(slice.left[offs..][0..size], std.mem.endsWith(u8, name, ".s")),
        }));
    } else |_| {}
}
