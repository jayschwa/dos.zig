const std = @import("std");
const fd_t = std.os.fd_t;

pub fn malloc(paragraphs: u16) !u16 {
    // TODO: Check for error.
    return asm volatile ("int $0x21"
        : [_] "={bx}" (-> u16)
        : [func] "{ah}" (@as(u8, 0x48)),
          [_] "{bx}" (paragraphs)
    );
}

pub fn free(segment: u16) void {
    // TODO: Check for error?
    asm volatile ("int $0x21"
        : // No outputs
        : [func] "{ah}" (@as(u8, 0x49)),
          [_] "{es}" (segment)
    );
}

pub fn exec(path: [*:0]const u8) !u16 {
    const param_block = [_]u16{0} ** 7;
    var errno: u16 = undefined;
    const flags = asm volatile (
        \\ int $0x21
        \\ pushfw
        \\ popw %[flags]
        : [flags] "=r" (-> u16),
          [errno] "={ax}" (errno)
        : [_] "{ax}" (@as(u16, 0x4b00)),
          [_] "{bx}" (&param_block),
          [_] "{dx}" (@ptrToInt(path))
        : "bx", "dx", "cc"
    );
    if (flags & 1 != 0)
        return switch (errno) {
            2 => error.FileNotFound,
            5 => error.AccessDenied,
            8 => error.OutOfMemory,
            11 => error.BadFormat,
            else => error.Unexpected,
            // NOTE: The following errors are not expected with the current implementation.
            // 1 => error.BadFunction,
            // 10 => error.BadEnvironment,
        };
    return asm ("int $0x21"
        : [_] "={ax}" (-> u16)
        : [_] "{ax}" (@as(u16, 0x4d00))
        : "cc"
    );
}

pub fn print(comptime format: []const u8, args: anytype) void {
    const writer = std.io.Writer(fd_t, error{}, write){
        .context = std.io.getStdErr().handle,
    };
    _ = writer.print(format, args) catch return;
}

fn write(context: fd_t, bytes: []const u8) !usize {
    // TODO: Handle errors.
    asm volatile ("int $0x21"
        : // No outputs
        : [_] "{ah}" (@as(u8, 0x40)),
          [_] "{bx}" (context),
          [_] "{cx}" (bytes.len),
          [_] "{dx}" (bytes.ptr)
        : "cc"
    );
    return bytes.len;
}
