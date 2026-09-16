const std = @import("std");

const dos = @import("dos.zig");

pub const panic = dos.debug.panic;

// This is necessary to pull in the start code.
comptime {
    _ = dos;
}

pub fn main() !void {
    try print("This is a DOS program written in Zig!\r\n", .{});

    try print("Let's calculate a Fibonacci number...\r\n", .{});
    var n: usize = undefined;

    while (true) {
        try print("Enter a small number: ", .{});
        var line_buf: [80]u8 = undefined;
        const line = readLine(&line_buf) orelse return error.EndOfStream;
        n = std.fmt.parseInt(usize, line, 10) catch |err| {
            try print("error: {s}\r\n", .{@errorName(err)});
            continue;
        };
        break;
    }

    try print("fib({}) = {}\r\n", .{ n, fib(n) });
}

fn fib(n: usize) usize {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

// TODO: Replace with `std.Io` interface.
fn readLine(buf: []u8) ?[]const u8 {
    var read_len: usize = 0;
    while (read_len < buf.len) {
        var byte: u8 = undefined;
        if (dos.read(dos.STDIN_FILENO, @ptrCast(&byte), 1) == 0) {
            if (read_len == 0) return null else break;
        }
        if (byte == '\r') break;
        if (byte == '\n') {
            if (read_len == 0) continue else break;
        }
        buf[read_len] = byte;
        read_len += 1;
    }
    return buf[0..read_len];
}

// TODO: Replace with `std.Io` interface.
fn print(comptime fmt: []const u8, args: anytype) !void {
    var buf: [128]u8 = undefined;
    const s = try std.fmt.bufPrint(&buf, fmt, args);
    _ = dos.write(dos.STDOUT_FILENO, s.ptr, s.len);
}
