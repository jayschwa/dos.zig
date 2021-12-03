const std = @import("std");
const Writer = std.io.Writer;

pub fn print(comptime format: []const u8, args: anytype) void {
    _ = writer.print(format, args) catch return;
}

pub const writer = Writer(void, error{}, write){
    .context = {},
};

pub fn write(context: void, bytes: []const u8) !usize {
    _ = context;
    for (bytes) |byte| asm volatile ("int $0x21"
        : // No outputs
        : [_] "{ah}" (@as(u8, 0x2)),
          [_] "{dl}" (byte),
    );
    return bytes.len;
}
