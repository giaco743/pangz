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

    const stats = try pacpng.parsePcapng(mmapped.data);
    std.debug.print(
        \\==================================================
        \\               PCAPNG FILE STATISTICS             
        \\==================================================
        \\ File Size:          {d} bytes
        \\ Total Blocks:       {d} (Sections: {d}, Interfaces: {d})
        \\
        \\ Capture Metrics:
        \\   Total Packets:    {d}
        \\   Captured Bytes:   {d} bytes
        \\   Original Bytes:   {d} bytes
        \\   Duration:         {d} ms
        \\
        \\ Performance & Throughput:
        \\   Packets / Sec:    {d} pps
        \\   Avg Packet Size:  {d} bytes
        \\   Throughput:       {d} bps ({d:.2} Mbps)
        \\
        \\ Block Breakdown:
        \\   Enhanced Packets (EPB): {d}
        \\   Simple Packets (SPB):   {d}
        \\   Interface Desc (IDB):   {d}
        \\   Name Resolution (NRB):  {d}
        \\   Interface Stats (ISB):  {d}
        \\   Other Blocks:           {d}
        \\==================================================
        \\
    , .{
        stats.size,
        stats.blocks,
        stats.sections,
        stats.interfaces,
        stats.packets,
        stats.captured_bytes,
        stats.original_bytes,
        stats.duration,
        stats.packets_sec,
        stats.avg_packet_size,
        stats.throughput_bps,
        @as(f64, @floatFromInt(stats.throughput_bps)) / 1_000_000.0,
        stats.block_types.epb,
        stats.block_types.spb,
        stats.block_types.idb,
        stats.block_types.nrb,
        stats.block_types.isb,
        stats.block_types.other,
    });
}
