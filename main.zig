const std = @import("std");
const mmap = @import("mmap.zig");
const pacpng = @import("pcapng.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var it = init.minimal.args.iterate();
    _ = it.next() orelse return error.ProgramMissing;
    const in = it.next() orelse return error.InputMissing;

    var mmapped = try mmap.MappedFile.open(io, in);
    defer mmapped.close(io);

    try pacpng.parsePcapng(mmapped.data);
}
