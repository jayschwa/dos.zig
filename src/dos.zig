const std = @import("std");
const File = std.fs.File;

pub const dpmi = @import("dos/dpmi.zig");

// Implement standard library operating system interfaces.
pub const system = @import("dos/system.zig");

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
