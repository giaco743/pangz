const std = @import("std");
const linux = std.os.linux;

pub const MappedFile = struct {
    file: std.Io.File,
    data: []const u8,

    pub fn open(io: std.Io, path: []const u8) !MappedFile {
        const file = try std.Io.Dir.cwd().openFile(io, path, .{});
        errdefer file.close(io);

        const stat = try file.stat(io);
        const len = stat.size;

        if (len == 0) {
            return .{
                .file = file,
                .data = &.{},
            };
        }

        const address = linux.mmap(
            null,
            len,
            linux.PROT{ .READ = true },
            .{ .TYPE = .PRIVATE },
            file.handle,
            0,
        );

        if (linux.errno(address) != .SUCCESS) {
            return error.MMapFailed;
        }

        const data: []const u8 =
            @as([*]const u8, @ptrFromInt(address))[0..len];

        return .{
            .file = file,
            .data = data,
        };
    }

    pub fn close(self: *MappedFile, io: std.Io) void {
        if (self.data.len != 0) {
            _ = linux.munmap(
                @constCast(self.data.ptr),
                self.data.len,
            );
        }

        self.file.close(io);
    }
};
