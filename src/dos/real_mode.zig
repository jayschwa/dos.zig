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
