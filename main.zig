const std = @import("std");
const iga = @import("iga.zig");
const mem = std.heap.page_allocator;

fn readEntries(reader: anytype, allocator: std.mem.Allocator) ![]iga.Entry64 {
    const len = try iga.mbRead(u64, reader);
    var lim_r = std.io.limitedReader(reader, len);
    const rdr = lim_r.reader();
    var array = try std.ArrayList(iga.Entry64).initCapacity(allocator, len / 7);
    errdefer array.deinit();
    while (lim_r.bytes_left > 0) {
        const entry = try iga.Entry64.read(rdr);
        std.debug.print("{}\n", .{entry});
        try array.append(entry);
    }
    std.debug.print("- end of entries -\n", .{});
    // std.debug.print(
    //     "avg bytes per entry {}\n",
    //     .{@intToFloat(f64, len) / @intToFloat(f64, array.items.len)},
    // );
    return array.toOwnedSlice();
}

fn readNames(reader: anytype, allocator: std.mem.Allocator, entries: []iga.Entry64) ![]u8 {
    const len = try iga.mbRead(u64, reader);

    var lim_rdr = std.io.limitedReader(reader, len);
    const lim_r = lim_rdr.reader();

    var nameBuf = try std.ArrayList(u8).initCapacity(allocator, len);
    errdefer nameBuf.deinit();
    for (entries, 0..) |*ent, i| {
        const name_begin = nameBuf.items.len;

        if (i + 1 < entries.len) {
            var n = entries[i + 1].filename_offset - ent.filename_offset;
            while (n > 0) : (n -= 1)
                try nameBuf.append(try iga.mbRead(u8, lim_r));
        } else {
            while (lim_rdr.bytes_left > 0)
                try nameBuf.append(try iga.mbRead(u8, lim_r));
        }

        ent.filename = nameBuf.items[name_begin..];
        std.debug.print("{s}\n", .{ent.filename.?});
    }
    std.debug.print("- end of names -\n", .{});
    return nameBuf.toOwnedSlice();
}

fn entryLT(context: ?void, lhs: iga.Entry64, rhs: iga.Entry64) bool {
    _ = context;
    return lhs.offset < rhs.offset;
}

pub fn main() !void {
    const argv = try std.process.argsAlloc(mem);
    defer std.process.argsFree(mem, argv);
    if (argv.len < 3) {
        std.debug.print("usage: ziga iga_file out_folder\n", .{});
        return error.NotEnoughArgs;
    }
    // const xor = argv.len > 3 and std.mem.eql(u8, argv[3][0..], "xor");
    // std.debug.print("xor = {}\n", .{xor});
    const infile = try std.fs.cwd().openFileZ(argv[1], .{});
    defer infile.close();
    const r = infile.reader();
    const hdr = try r.readStruct(iga.IGAHdr);
    if (hdr.checkSig() == false)
        return error.InvalidSig;
    const entries = try readEntries(r, mem);
    defer mem.free(entries);
    const nameBuf = try readNames(r, mem, entries);
    defer mem.free(nameBuf);
    std.sort.sort(iga.Entry64, entries, @as(?void, null), entryLT);
    var offset: u64 = 0;
    var buffer: [4096]u8 = undefined;
    const outPrefix = argv[2][0..];
    var outName = try std.ArrayList(u8).initCapacity(mem, outPrefix.len + 32);
    defer outName.deinit();
    try outName.appendSlice(outPrefix);
    if (outName.items.len > 0 and outName.items[outName.items.len - 1] != '/')
        try outName.append('/');
    const prefixLen = outName.items.len;
    for (entries) |ent| {
        if (offset != ent.offset) {
            try infile.seekBy(@intCast(i64, ent.offset) -% @intCast(i64, offset));
            offset = ent.offset;
        }
        try outName.resize(prefixLen);
        try outName.appendSlice(ent.filename.?);
        std.debug.print("-> {s}\n", .{outName.items});
        const outfile = try std.fs.cwd().createFile(outName.items, .{});
        defer outfile.close();
        var state: u64 = 0;
        var lim_rdr = std.io.limitedReader(r, ent.length);
        const lim_r = lim_rdr.reader();
        while (lim_rdr.bytes_left > 0) {
            const cnt = try lim_r.readAll(&buffer);
            if (cnt == 0)
                return error.TruncateIGA;
            iga.decrypt(buffer[0..cnt], &state, std.mem.endsWith(u8, outName.items, ".s"));
            try outfile.writeAll(buffer[0..cnt]);
        }
        offset += ent.length;
    }
}
