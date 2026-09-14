const std = @import("std");
const assert = std.debug.assert;
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var args_iter = try init.minimal.args.iterateAllocator(init.arena.allocator());
    defer args_iter.deinit();

    assert(args_iter.skip());

    var stdout_writer_buf: [4096]u8 = undefined;
    var stdout_writer = Io.File.stdout().writerStreaming(io, &stdout_writer_buf);

    while (args_iter.next()) |path| {
        var file = try Io.Dir.cwd().openFile(io, path, .{});
        defer file.close(io);
        var file_reader = file.readerStreaming(io, &.{});
        _ = try file_reader.interface.streamRemaining(&stdout_writer.interface);
    }

    try stdout_writer.flush();
}
