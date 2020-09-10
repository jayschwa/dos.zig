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

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace) noreturn {
    std.debug.print("panic: {}\r\n", .{msg});
    std.os.abort();
}

// TODO: Integrate with standard library fs module.
pub fn openFile(path: [*:0]const u8) !File {
    const fd = os.system.open(path, .ReadOnly);
    return File{ .handle = fd };
}
