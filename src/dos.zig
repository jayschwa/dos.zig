const std = @import("std");

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
    error_code = if (regs_out.flags & 1 != 0)
        int21(.{ .eax = 0x5900, .ebx = 0 }).ax // Extended error code.
    else
        0;
    return regs_out;
}

pub fn exit(status: u8) noreturn {
    const func: u16 = 0x4c00;
    asm volatile ("int $0x21"
        : // No outputs
        : [_] "{ax}" (func | status),
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
    const regs = int21(.{
        .eax = 0x3d00 | (flags & 3),
        .edx = 0,
        .ds = transfer_buffer.real_mode_segment,
    });
    return regs.ax;
}

pub fn close(handle: fd_t) void {
    _ = int21(.{
        .eax = 0x3e00,
        .ebx = handle,
    });
}

pub fn read(handle: fd_t, buf: [*]u8, count: usize) u16 {
    const len = @min(count, transfer_buffer.len);
    const regs = int21(.{
        .eax = 0x3f00,
        .ebx = handle,
        .ecx = len,
        .edx = 0,
        .ds = transfer_buffer.real_mode_segment,
    });
    const actual_read_len = regs.ax;
    if (error_code == 0) {
        transfer_buffer.read(buf[0..actual_read_len]);
    }
    return actual_read_len;
}

pub fn write(handle: fd_t, buf: [*]const u8, count: usize) u16 {
    const len = @min(count, transfer_buffer.len);
    transfer_buffer.write(buf[0..len]);
    const regs = int21(.{
        .eax = 0x4000,
        .ebx = handle,
        .ecx = len,
        .edx = 0,
        .ds = transfer_buffer.real_mode_segment,
    });
    return regs.ax;
}

pub fn fsync(handle: fd_t) u16 {
    const regs = int21(.{
        .eax = 0x6800,
        .ebx = handle,
    });
    return regs.ax;
}

pub fn lseek(handle: fd_t, offset: off_t, whence: u8) off_t {
    const regs = int21(.{
        .eax = @as(u16, 0x4200) | whence,
        .ebx = handle,
        .ecx = @as(u16, @intCast(offset >> 16)),
        .edx = @as(u16, @truncate(offset)),
    });
    return @intCast(@as(u32, regs.dx) << 16 | regs.ax);
}
