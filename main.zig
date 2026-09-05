const std = @import("std");
const mmap = @import("mmap.zig");
const pacpng = @import("pcapng.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var it = init.minimal.args.iterate();
    _ = it.next() orelse return error.ProgramMissing;
    const in = it.next() orelse return error.InputMissing;
    const out = it.next() orelse return error.OutputMissing;

    var mmapped = try mmap.MappedFile.open(io, in);
    defer mmapped.close(io);

    var wbuf: [1024 * 1024]u8 = undefined;
    const outfile = try std.Io.Dir.cwd().createFile(io, out, .{ .truncate = true });
    var writer_impl = outfile.writer(io, &wbuf);
    const writer = &writer_impl.interface;
    try writer.writeAll(mmapped.data);
}
