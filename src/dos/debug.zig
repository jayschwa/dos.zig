const std = @import("std");

const dos = @import("../dos.zig");

pub const panic = std.debug.FullPanic(struct {
    fn panicFn(message: []const u8, first_trace_address: ?usize) noreturn {
        _ = first_trace_address; // TODO: Print a stack trace.
        for ("panic: ") |c| dos.displayChar(c);
        for (message) |c| dos.displayChar(c);
        for ("\r\n") |c| dos.displayChar(c);
        @trap();
    }
}.panicFn);
