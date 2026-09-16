const std = @import("std");
const maxInt = std.math.maxInt;

pub const dpmi = @import("dos/dpmi.zig");
const callRealMode = dpmi.translation.callRealMode;
const RegisterInput = dpmi.translation.RegisterInput;
const RegisterOutput = dpmi.translation.RegisterOutput;

// This forces the start.zig file to be imported, and the comptime logic inside that
// file decides whether to export any appropriate start symbols.
comptime {
    _ = @import("dos/start.zig");
}

pub const fd_t = u16;
pub const mode_t = u8;
pub const off_t = i32;

pub const PATH_MAX = 260;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const O_RDONLY = 0;
pub const O_WRONLY = 1;
pub const O_RDWR = 2;

pub const SEEK_SET = 0;
pub const SEEK_CUR = 1;
pub const SEEK_END = 2;

/// Error code of the last DOS system call.
pub threadlocal var error_code: u16 = 0;

/// Buffer in DOS memory for transferring data with system calls.
pub var transfer_buffer: dpmi.DosMemoryBlock = undefined;

fn int21(regs: RegisterInput) RegisterOutput {
    const regs_out = callRealMode(.{ .interrupt = 0x21 }, regs, .{}) catch |err| switch (err) {
        error.StackCopyWouldOverflow => unreachable,
        error.LinearMemoryUnavailable,
        error.PhysicalMemoryUnavailable,
        error.BackingStoreUnavailable,
        => @panic(@errorName(err)),
    };
    error_code = if (regs_out.flags.carry)
        int21(.{ .eax = 0x5900, .ebx = 0 }).ax // Extended error code.
    else
        0;
    return regs_out;
}

pub fn exit(status: u8) noreturn {
    asm volatile ("int $0x21"
        : // No outputs
        : [_] "{ah}" (@as(u8, 0x4c)),
          [_] "{al}" (status),
    );
    unreachable;
}

pub fn open(file_path: [*:0]const u8, flags: u32, mode: mode_t) fd_t {
    _ = mode;
    // TODO: Can mode be reasonably mapped onto DOS 3.1 sharing mode bits?
    // TODO: Use long filename open (int 0x21, ax=0x716c) if it's available.
    const len = std.mem.len(file_path) + 1;
    // TODO: Fail if len exceeds transfer buffer size.
    transfer_buffer.write(file_path[0..len]);
    const regs = int21(.init(.{
        .ah = 0x3d,
        .al = @as(u8, @intCast(flags & 3)),
        .ds = transfer_buffer.real_mode_segment,
        .dx = 0,
    }));
    return regs.ax;
}

pub fn close(handle: fd_t) void {
    _ = int21(.init(.{
        .ah = 0x3e,
        .bx = handle,
    }));
}

pub fn read(handle: fd_t, buf: [*]u8, count: usize) u16 {
    const len = @min(count, transfer_buffer.len, maxInt(u16));
    const regs = int21(.init(.{
        .ah = 0x3f,
        .bx = handle,
        .cx = len,
        .ds = transfer_buffer.real_mode_segment,
        .dx = 0,
    }));
    const actual_read_len = regs.ax;
    if (error_code == 0) {
        transfer_buffer.read(buf[0..actual_read_len]);
    }
    return actual_read_len;
}

pub fn write(handle: fd_t, buf: [*]const u8, count: usize) u16 {
    const len = @min(count, transfer_buffer.len, maxInt(u16));
    transfer_buffer.write(buf[0..len]);
    const regs = int21(.init(.{
        .ah = 0x40,
        .bx = handle,
        .cx = len,
        .ds = transfer_buffer.real_mode_segment,
        .dx = 0,
    }));
    return regs.ax;
}

pub fn fsync(handle: fd_t) u16 {
    const regs = int21(.init(.{
        .ah = 0x68,
        .bx = handle,
    }));
    return regs.ax;
}

pub fn lseek(handle: fd_t, offset: off_t, whence: u8) off_t {
    const raw_offset: u32 = @bitCast(offset);
    const regs = int21(.init(.{
        .ah = 0x42,
        .al = whence,
        .bx = handle,
        .cx = @as(u16, @truncate(raw_offset >> 16)),
        .dx = @as(u16, @truncate(raw_offset)),
    }));
    return @intCast(@as(u32, regs.dx) << 16 | regs.ax);
}
