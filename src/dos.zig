const std = @import("std");

pub const dpmi = @import("dos/dpmi.zig");

// This forces the start.zig file to be imported, and the comptime logic inside that
// file decides whether to export any appropriate start symbols.
comptime {
    _ = @import("dos/start.zig");
}

pub const PATH_MAX = 260;

/// Buffer in DOS memory for transferring data with system calls.
pub var transfer_buffer: dpmi.DosMemoryBlock = undefined;

fn int21(registers: dpmi.RealModeRegisters) dpmi.RealModeRegisters {
    var regs = registers;
    dpmi.simulateInterrupt(0x21, &regs);
    return regs;
}

pub fn exit(status: u8) noreturn {
    const func: u16 = 0x4c00;
    asm volatile ("int $0x21"
        : // No outputs
        : [_] "{ax}" (func | status),
    );
    unreachable;
}

// TODO: Move to separate file?
pub const File = struct {
    handle: Handle,

    pub const Handle = u16;

    pub const stdin: File = .{ .handle = 0 };
    pub const stdout: File = .{ .handle = 1 };
    pub const stderr: File = .{ .handle = 2 };

    pub const OpenOptions = struct {
        access: Access = .read_only,
        share: Share = .compatibility,
        inherit: bool = true,

        pub const Access = enum(u8) {
            read_only = 0x00,
            write_only = 0x01,
            read_write = 0x02,
        };

        pub const Share = enum(u8) {
            compatibility = 0x00,
            deny_read_write = 0x10,
            deny_write = 0x20,
            deny_read = 0x30,
            deny_none = 0x40,
        };

        fn int(options: OpenOptions) u8 {
            return @intFromEnum(options.access) |
                @intFromEnum(options.share) |
                @as(u8, if (options.inherit) 0 else 0x80);
        }
    };

    pub const OpenError = error{
        FileNotFound,
        PathNotFound,
        TooManyOpenFiles,
        AccessDenied,
        InvalidAccess,
    };

    // https://www.ctyme.com/intr/rb-2779.htm
    // https://archive.org/details/microsoftmsdospr0000unse/page/275
    pub fn open(path: []const u8, options: OpenOptions) OpenError!File {
        transfer_buffer.write(path); // TODO: Bounds check
        transfer_buffer.writeAt(&.{0}, path.len);
        const regs = int21(.{
            .eax = @as(u16, 0x3d00) | options.int(),
            .edx = 0,
            .ds = transfer_buffer.real_mode_segment,
        });
        return if (regs.carryFlag()) switch (regs.ax()) {
            0x02 => error.FileNotFound,
            0x03 => error.PathNotFound,
            0x04 => error.TooManyOpenFiles,
            0x05 => error.AccessDenied,
            0x0c => error.InvalidAccess,
            else => unreachable,
        } else .{ .handle = regs.ax() };
    }

    // https://www.ctyme.com/intr/rb-2782.htm
    // https://archive.org/details/microsoftmsdospr0000unse/page/277
    pub fn close(file: File) void {
        const regs = int21(.{
            .eax = 0x3e00,
            .ebx = file.handle,
        });
        if (regs.carryFlag()) switch (regs.ax()) {
            0x06 => invalidHandle(file.handle),
            else => unreachable,
        };
    }

    pub const ReadError = error{
        AccessDenied,
    };

    // https://www.ctyme.com/intr/rb-2783.htm
    // https://archive.org/details/microsoftmsdospr0000unse/page/278
    pub fn read(file: File, buffer: []u8) ReadError!u16 {
        // TODO: Decide what to do if `buffer` is larger than the transfer buffer.
        const regs = int21(.{
            .eax = 0x3f00,
            .ebx = file.handle,
            .ecx = @min(buffer.len, transfer_buffer.len),
            .edx = 0,
            .ds = transfer_buffer.real_mode_segment,
        });
        return if (regs.carryFlag()) switch (regs.ax()) {
            0x05 => error.AccessDenied,
            0x06 => invalidHandle(file.handle),
            else => unreachable,
        } else blk: {
            const len = regs.ax();
            transfer_buffer.read(buffer[0..len]);
            break :blk len;
        };
    }

    pub const WriteError = error{
        AccessDenied,
    };

    // https://www.ctyme.com/intr/rb-2791.htm
    // archive.org/details/microsoftmsdospr0000unse/page/280
    pub fn write(file: File, buffer: []const u8) WriteError!u16 {
        // TODO: Decide what to do if `buffer` is larger than the transfer buffer.
        const len = @min(buffer.len, transfer_buffer.len);
        transfer_buffer.write(buffer[0..len]);
        const regs = int21(.{
            .eax = 0x4000,
            .ebx = file.handle,
            .ecx = len,
            .edx = 0,
            .ds = transfer_buffer.real_mode_segment,
        });
        return if (regs.carryFlag()) switch (regs.ax()) {
            0x05 => error.AccessDenied,
            0x06 => invalidHandle(file.handle),
            else => unreachable,
        } else regs.ax();
    }

    pub const SeekOffset = union(Origin) {
        start: u32,
        current: i32,
        end: i32,

        const Origin = enum(u8) {
            start = 0x00,
            current = 0x01,
            end = 0x02,
        };
    };

    // https://www.ctyme.com/intr/rb-2799.htm
    // https://archive.org/details/microsoftmsdospr0000unse/page/282
    pub fn seek(file: File, offset: SeekOffset) u32 {
        const raw_offset: u32 = switch (offset) {
            .start => |v| v,
            .current, .end => |v| @bitCast(v),
        };
        const regs = int21(.{
            .eax = @as(u16, 0x4200) | @intFromEnum(offset),
            .ebx = file.handle,
            .ecx = raw_offset >> 16,
            .edx = raw_offset & 0xffff,
        });
        return if (regs.carryFlag()) switch (regs.ax()) {
            0x01 => unreachable, // Bad move method
            0x06 => invalidHandle(file.handle),
            else => unreachable,
        } else (regs.edx << 16) | regs.ax();
    }

    // https://www.ctyme.com/intr/rb-3170.htm
    // https://archive.org/details/microsoftmsdospr0000unse/page/390
    pub fn commit(file: File) !void {
        // TODO: Should this be named `commit`, `flush`, or `sync`?
        const regs = int21(.{
            .eax = 0x6800,
            .ebx = file.handle,
        });
        if (regs.carryFlag()) switch (regs.ax()) {
            0x06 => invalidHandle(file.handle),
            else => @panic("FIXME"), // Error set is not well-documented.
        };
    }

    fn invalidHandle(handle: Handle) noreturn {
        _ = handle;
        @panic("invalid handle");
    }
};
