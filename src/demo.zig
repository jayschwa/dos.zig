const dos = @import("dos.zig");

// Force start code to be linked
comptime {
    _ = @import("dos/start.zig");
}

pub fn main() void {
    const msg = "Hello from DOS!\r\n";
    _ = dos.system.write(dos.system.STDOUT_FILENO, msg.ptr, msg.len);
}
