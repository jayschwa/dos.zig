const std = @import("std");
const File = std.fs.File;

// This implements standard library operating system abstractions.
pub const os = struct {
    pub const bits = @import("dos/bits.zig");
    pub const system = @import("dos/system.zig");
};

// This forces the start.zig file to be imported, and the comptime logic inside that
// file decides whether to export any appropriate start symbols.
comptime {
    _ = @import("dos/start.zig");
}

// TODO: Integrate with standard library fs module.
pub fn openFile(path: []const u8) !File {
    const fd = try std.os.open(path, std.os.O_RDONLY, 0);
    return File{ .handle = fd };
}
