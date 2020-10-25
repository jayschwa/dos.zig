const root = @import("root");
const std = @import("std");

const dpmi = @import("dpmi.zig");
const safe = @import("safe.zig");
const system = @import("system.zig");

comptime {
    if (@hasDecl(root, "main")) @export(_start, .{ .name = "_start" });
}

// Initial stack pointer set by the linker script.
extern const _stack_ptr: opaque {};

fn _start() callconv(.Naked) noreturn {
    // Use the data segment to initialize the extended and stack segments.
    asm volatile (
        \\ mov %%ds, %%dx
        \\ mov %%dx, %%es
        \\ mov %%dx, %%ss
        :
        : [_] "{esp}" (&_stack_ptr)
        : "dx", "ds", "es", "ss"
    );
    // TODO: Use the transfer buffer provided by the stub loader.
    system.transfer_buffer = dpmi.DosMemBlock.alloc(0x4000) catch |err| {
        safe.print("error: {}\r\n", .{@errorName(err)});
        std.os.abort();
    };
    std.os.exit(std.start.callMain());
}
