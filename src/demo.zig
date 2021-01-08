const std = @import("std");

pub const os = @import("dos");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("This is a DOS program written in Zig!\r\n", .{});

    try stdout.print("Let's calculate a Fibonacci number...\r\n", .{});
    var n: usize = undefined;
    const stdin = std.io.getStdIn().reader();

    while (true) {
        try stdout.print("Enter a small number: ", .{});
        var line_buf: [80]u8 = undefined;
        var line = (try stdin.readUntilDelimiterOrEof(&line_buf, '\r')).?;
        if (line[line.len - 1] == '\r') line = line[0..(line.len - 1)];
        n = std.fmt.parseInt(usize, line, 10) catch |err| {
            // TODO: Drain following '\n' in DOSEMU2. May need buffered reader?
            try stdout.print("error: {s}\r\n", .{@errorName(err)});
            continue;
        };
        break;
    }

    try stdout.print("fib({}) = {}\r\n", .{ n, fib(n) });
}

fn fib(n: usize) usize {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}
