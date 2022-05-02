pub const dpmi = @import("dos/dpmi.zig");

// Implement standard library operating system interfaces.
pub const system = @import("dos/system.zig");

// This forces the start.zig file to be imported, and the comptime logic inside that
// file decides whether to export any appropriate start symbols.
comptime {
    _ = @import("dos/start.zig");
}
