//! DosMemoryBlock represents an allocated block of memory that resides below
//! the 1 MiB address in physical memory and is accessible to DOS.

const std = @import("std");
const mem = std.mem;

const Self = @This();
const Segment = @import("Segment.zig");

protected_mode_segment: Segment,
real_mode_segment: u16,
len: usize,

pub fn create(size: u20) !Self {
    const aligned_size = mem.alignForwardGeneric(@TypeOf(size), size, 16);
    var protected_selector: u16 = 0;
    var real_segment: u16 = 0;
    const flags = asm volatile (
        \\ int $0x31
        \\ pushfw
        \\ popw %[flags]
        : [flags] "=r" (-> u16),
          [_] "={ax}" (real_segment),
          [_] "={dx}" (protected_selector),
        : [_] "{ax}" (@as(u16, 0x100)),
          [_] "{bx}" (aligned_size / 16),
        : "cc"
    );

    // TODO: Better error handling.
    if (flags & 1 != 0) return error.DpmiAllocError;

    return .{
        .protected_mode_segment = .{ .selector = protected_selector },
        .real_mode_segment = real_segment,
        .len = aligned_size,
    };
}

pub fn read(self: Self, buffer: []u8) void {
    return self.protected_mode_segment.read(buffer);
}

pub fn write(self: Self, bytes: []const u8) void {
    return self.protected_mode_segment.write(bytes);
}
