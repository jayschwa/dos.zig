const root = @import("root");
const std = @import("std");
const PATH_MAX = std.os.PATH_MAX;

const dpmi = @import("dpmi.zig");
const FarPtr = @import("far_ptr.zig").FarPtr;
const real_mode = @import("real_mode.zig");
const safe = @import("safe.zig");
const system = @import("system.zig");

comptime {
    if (@hasDecl(root, "main")) @export(_start, .{ .name = "_start" });
}

pub var ds: ?u16 = null;

const in_real_mode = std.builtin.abi == .code16;

fn _start() callconv(.Naked) noreturn {
    if (in_real_mode) {
        zero_bss();
        ds = asm ("mov %%ds, %[seg]"
            : [seg] "=r" (-> u16)
        );
        enterProtectedModeOrAbort();
    } else {
        system.initTransferBuffer() catch |err| printAndAbort("error: {}\r\n", .{@errorName(err)});
    }
    std.os.exit(std.start.callMain());
}

extern var _bss_start: u8;
extern var _bss_end: u8;

fn zero_bss() void {
    const len = @ptrToInt(&_bss_end) - @ptrToInt(&_bss_start);
    const bss = @ptrCast([*]u8, &_bss_start)[0..len];
    std.mem.set(u8, bss, 0);
}

fn enterProtectedModeOrAbort() void {
    // Prepare DPMI host path generator.
    const dpmi_host = "CWSDPMI.EXE";
    const environment = FarPtr{ .segment = @intToPtr(*u16, 0x2c).* };
    var dpmi_host_path_iter = PathComboIterator{ .env = environment, .file = dpmi_host };

    var mode_switch = dpmi.enterProtectedMode();

    // TODO: Simplify condition after https://github.com/ziglang/zig/issues/1302 is completed.
    while (if (mode_switch) false else |err| err == error.NoDpmi) {
        var buffer: [PATH_MAX]u8 = undefined;
        const dpmi_host_path = dpmi_host_path_iter.next(&buffer) orelse break;
        if (real_mode.exec(dpmi_host_path)) |exit_code| {
            if (exit_code != 0x300) printAndAbort("{} exited with unexpected code: {x}\r\n", .{ dpmi_host, exit_code });
        } else |err| switch (err) {
            error.FileNotFound => {},
            else => |e| printAndAbort("Failed to start {}: {}\r\n", .{ dpmi_host, @errorName(e) }),
        }
        mode_switch = dpmi.enterProtectedMode(); // TODO: Try this in continue expression.
    }

    mode_switch catch |err| {
        const msg = switch (err) {
            error.NoDpmi => "No DPMI detected. Add CWSDPMI.EXE to PATH.",
            error.No32BitSupport => "DPMI does not support 32-bit programs.",
            error.ProtectedModeSwitchFailed => "Protected mode switch failed.",
        };
        printAndAbort("Error: {}\r\n", .{msg});
    };
}

const PathComboIterator = struct {
    env: FarPtr,
    file: [:0]const u8,
    state: enum { FileOnly, FindPath, GetPath, Done } = .FileOnly,

    fn next(self: *PathComboIterator, buffer: []u8) ?[*:0]const u8 {
        while (true) switch (self.state) {
            .FileOnly => return self.fileOnly(),
            .FindPath => self.findPath(),
            .GetPath => if (self.getPath(buffer)) |path| return path,
            .Done => return null,
        };
    }

    fn fileOnly(self: *PathComboIterator) [*:0]const u8 {
        self.state = .FindPath;
        return self.file.ptr;
    }

    // findPath increments the environment pointer until it reaches the PATH
    // variable or the end of the enviroment data (two zeros).
    fn findPath(self: *PathComboIterator) void {
        var buffer = [_]u8{0} ** "PATH=".len;
        while (true) {
            if (self.env.reader().readUntilDelimiterOrEof(&buffer, 0)) |bytes| {
                if (bytes == null or bytes.?.len == 0) {
                    self.state = .Done;
                    return;
                }
                continue; // Variable is too small to be (valid) PATH.
            } else |err| switch (err) {
                error.StreamTooLong => if (std.mem.eql(u8, &buffer, "PATH=")) {
                    self.env.offset -= 1;
                    self.state = .GetPath;
                    return;
                },
            }
            // Skip to start of next environment variable.
            self.env.reader().skipUntilDelimiterOrEof(0) catch unreachable;
        }
    }

    // getPath returns a single path (delimited by semicolon) from the PATH value.
    // findPath must be called once before the first call to getPath.
    fn getPath(self: *PathComboIterator, buffer: []u8) ?[*:0]u8 {
        std.debug.assert(buffer.len >= PATH_MAX);
        var env = self.env.reader();
        var path = std.io.fixedBufferStream(buffer);

        // Copy characters from the environment to the path buffer until a sentinel is encountered.
        var char = env.readByte() catch unreachable;
        while (char != ';' and char != 0) : (char = env.readByte() catch unreachable)
            path.writer().writeByte(char) catch unreachable;

        // If the sentinel is zero, it's the end of the PATH variable.
        if (char == 0) self.state = .Done;

        const path_buf = path.getWritten();
        if (path_buf.len == 0) return null;

        // Append a path separator if necessary.
        if (path_buf[path_buf.len - 1] != '\\') path.writer().writeByte('\\') catch unreachable;

        // Append filename and zero sentinel.
        path.writer().writeAll(self.file) catch unreachable;
        path.writer().writeByte(0) catch unreachable;

        return @ptrCast([*:0]u8, path.getWritten().ptr);
    }
};

fn printAndAbort(comptime format: []const u8, args: anytype) noreturn {
    if (in_real_mode) real_mode.print(format, args) else safe.print(format, args);
    std.os.abort();
}
