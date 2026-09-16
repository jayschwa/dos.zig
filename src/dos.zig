const std = @import("std");
const maxInt = std.math.maxInt;

pub const debug = @import("dos/debug.zig");
pub const dpmi = @import("dos/dpmi.zig");
const callRealMode = dpmi.translation.callRealMode;
const RegisterInput = dpmi.translation.RegisterInput;
const RegisterOutput = dpmi.translation.RegisterOutput;
pub const File = @import("dos/File.zig");

// This forces the start.zig file to be imported, and the comptime logic inside that
// file decides whether to export any appropriate start symbols.
comptime {
    _ = @import("dos/start.zig");
}

pub const PATH_MAX = 260;

/// Buffer in DOS memory for transferring data with system calls.
pub var transfer_buffer: dpmi.DosMemoryBlock = undefined;

pub fn int21(regs: RegisterInput) RegisterOutput {
    return callRealMode(.{ .interrupt = 0x21 }, regs, .{}) catch |err| switch (err) {
        error.StackCopyWouldOverflow => unreachable,
        error.LinearMemoryUnavailable,
        error.PhysicalMemoryUnavailable,
        error.BackingStoreUnavailable,
        => @panic(@errorName(err)),
    };
}

pub fn exit(status: u8) noreturn {
    asm volatile ("int $0x21"
        : // No outputs
        : [_] "{ah}" (@as(u8, 0x4c)),
          [_] "{al}" (status),
    );
    unreachable;
}

// https://www.ctyme.com/intr/rb-2554.htm
pub fn displayChar(char: u8) void {
    _ = asm volatile ("int $0x21"
        : [_] "={al}" (-> u8),
        : [_] "{ah}" (@as(u8, 0x02)),
          [_] "{dl}" (char),
    );
}
