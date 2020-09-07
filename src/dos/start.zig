const root = @import("root");
const std = @import("std");
const dpmi = @import("dpmi.zig");
const real_mode = @import("real_mode.zig");
const safe = @import("safe.zig");
const system = @import("system.zig");

comptime {
    if (@hasDecl(root, "main")) @export(_start, .{ .name = "_start" });
}

pub var ds: ?u16 = null;

fn _start() callconv(.Naked) noreturn {
    if (std.builtin.abi == .code16) {
        zero_bss();
        ds = asm ("mov %%ds, %[seg]"
            : [seg] "=r" (-> u16)
        );
        dpmi.enterProtectedMode() catch |err| {
            // FIXME: This code path blows up in DOSBox-X.
            const msg = switch (err) {
                error.NoDpmi => "No DPMI detected.",
                error.No32BitSupport => "DPMI does not support 32-bit programs.",
                error.ProtectedModeSwitchFailed => "Protected mode switch failed.",
            };
            real_mode.print("Error: {}\r\n", .{msg});
            std.os.abort();
        };
    } else {
        system.initTransferBuffer() catch |err| {
            safe.print("error: {}\r\n", .{@errorName(err)});
            std.os.abort();
        };
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
