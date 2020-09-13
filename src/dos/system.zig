const std = @import("std");
const panic = std.debug.panic;

usingnamespace @import("bits.zig");
const dpmi = @import("dpmi.zig");
const FarPtr = @import("real_mode.zig").FarPtr;
const start = @import("start.zig");

const in_dos_mem = std.builtin.abi == .code16;

fn int21(registers: dpmi.RealModeRegisters) dpmi.RealModeRegisters {
    var regs = registers;
    dpmi.simulateInterrupt(0x21, &regs);
    return regs;
}

var transfer_buffer: ?dpmi.DosMemBlock = null;

pub fn initTransferBuffer() !void {
    transfer_buffer = try dpmi.DosMemBlock.alloc(0x4000);
}

pub fn copyToRealModeBuffer(bytes: []const u8) FarPtr {
    if (in_dos_mem)
        return FarPtr{
            .offset = @intCast(u16, @ptrToInt(bytes.ptr)),
            .segment = start.ds.?,
        };
    transfer_buffer.?.protected_mode_segment.writeAt(bytes, 0);
    return FarPtr{
        .offset = 0,
        .segment = transfer_buffer.?.real_mode_segment,
    };
}

pub fn abort() noreturn {
    exit(1);
}

pub fn exit(status: u8) noreturn {
    const func: u16 = 0x4c00;
    asm volatile ("int $0x21"
        : // No outputs
        : [_] "{ax}" (func | status)
    );
    unreachable;
}

pub fn open(file_path: [*:0]const u8, flags: u32, mode: mode_t) fd_t {
    // TODO: Can mode be reasonably mapped onto DOS 3.1 sharing mode bits?
    // TODO: Use long filename open (int 0x21, ax=0x716c) if it's available.
    const len = std.mem.len(file_path) + 1;
    // TODO: Fail if len exceeds transfer buffer size.
    const ptr = copyToRealModeBuffer(file_path[0..len]);
    const regs = int21(.{
        .eax = 0x3d00 | (flags & 3),
        .edx = ptr.offset,
        .ds = ptr.segment,
    });
    // TODO: Check for error in carry flag.
    return regs.ax();
}

pub fn close(handle: fd_t) void {
    const regs = int21(.{
        .eax = 0x3e00,
        .ebx = handle,
    });
    // TODO: Check for error in carry flag.
}

pub fn read(handle: fd_t, buf: [*]u8, count: usize) u16 {
    // TODO: Cleanup ugly code.
    const ptr = if (in_dos_mem)
        FarPtr{
            .offset = @intCast(u16, @ptrToInt(buf)),
            .segment = start.ds.?,
        }
    else
        FarPtr{
            .offset = 0,
            .segment = transfer_buffer.?.real_mode_segment,
        };
    const len = if (in_dos_mem) count else std.math.min(count, transfer_buffer.?.len);

    const regs = int21(.{
        .eax = 0x3f00,
        .ebx = handle,
        .ecx = len,
        .edx = ptr.offset,
        .ds = ptr.segment,
    });
    // TODO: Check for error in carry flag.
    const actual_read_len = regs.ax();
    if (!in_dos_mem) transfer_buffer.?.protected_mode_segment.readFrom(buf[0..actual_read_len], 0);
    return actual_read_len;
}

pub fn write(handle: fd_t, buf: [*]const u8, count: usize) u16 {
    const ptr = copyToRealModeBuffer(buf[0..count]);
    const len = if (in_dos_mem) count else std.math.min(count, transfer_buffer.?.len);
    const regs = int21(.{
        .eax = 0x4000,
        .ebx = handle,
        .ecx = len,
        .edx = ptr.offset,
        .ds = ptr.segment,
    });
    // TODO: Check for error in carry flag.
    return regs.ax();
}

pub fn lseek(handle: fd_t, offset: off_t, whence: u8) off_t {
    const regs = int21(.{
        .eax = @as(u16, 0x4200) | whence,
        .ebx = handle,
        .ecx = @intCast(u16, offset >> 16),
        .edx = @intCast(u16, offset),
    });
    // TODO: Check for error in carry flag.
    return @intCast(off_t, (regs.edx << 16) | regs.ax());
}

pub fn pread(handle: fd_t, buf: [*]u8, count: usize, offset: u64) u16 {
    // TODO: Handle errors.
    const original_offset = lseek(handle, 0, SEEK_CUR);
    defer _ = lseek(handle, original_offset, SEEK_SET);
    _ = lseek(handle, @intCast(off_t, offset), SEEK_SET);
    return read(handle, buf, count);
}

pub fn getErrno(rc: anytype) u16 {
    // TODO: Return error code from DOS int 0x21 calls.
    return 0;
}

pub fn sched_yield() void {
    // TODO: Yield via DPMI (if present).
    // See: http://www.delorie.com/djgpp/doc/dpmi/api/2f1680.html
}
