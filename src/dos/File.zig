const File = @This();

const std = @import("std");
const panic = std.debug.panic;
const maxInt = std.math.maxInt;

const dos = @import("../dos.zig");

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
    dos.transfer_buffer.write(path); // FIXME: Bounds check
    dos.transfer_buffer.writeAt(&.{0}, path.len);
    const regs = dos.int21(.init(.{
        .ah = 0x3d,
        .al = options.int(),
        .ds = dos.transfer_buffer.real_mode_segment,
        .dx = 0,
    }));
    return if (regs.flags.carry) switch (regs.ax) {
        0x02 => error.FileNotFound,
        0x03 => error.PathNotFound,
        0x04 => error.TooManyOpenFiles,
        0x05 => error.AccessDenied,
        0x0c => error.InvalidAccess,
        else => unreachable,
    } else .{ .handle = regs.ax };
}

// https://www.ctyme.com/intr/rb-2782.htm
// https://archive.org/details/microsoftmsdospr0000unse/page/277
pub fn close(file: File) void {
    const regs = dos.int21(.init(.{
        .ah = 0x3e,
        .bx = file.handle,
    }));
    if (regs.flags.carry) switch (regs.ax) {
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
    const len = @min(buffer.len, dos.transfer_buffer.len, maxInt(u16));
    const regs = dos.int21(.init(.{
        .ah = 0x3f,
        .bx = file.handle,
        .cx = len,
        .ds = dos.transfer_buffer.real_mode_segment,
        .dx = 0,
    }));
    return if (regs.flags.carry) switch (regs.ax) {
        0x05 => error.AccessDenied,
        0x06 => invalidHandle(file.handle),
        else => unreachable,
    } else blk: {
        dos.transfer_buffer.read(buffer[0..regs.ax]);
        break :blk regs.ax;
    };
}

pub const WriteError = error{
    AccessDenied,
};

// https://www.ctyme.com/intr/rb-2791.htm
// https://archive.org/details/microsoftmsdospr0000unse/page/280
pub fn write(file: File, buffer: []const u8) WriteError!u16 {
    const len = @min(buffer.len, dos.transfer_buffer.len, maxInt(u16));
    dos.transfer_buffer.write(buffer[0..len]);
    const regs = dos.int21(.init(.{
        .ah = 0x40,
        .bx = file.handle,
        .cx = len,
        .ds = dos.transfer_buffer.real_mode_segment,
        .dx = 0,
    }));
    return if (regs.flags.carry) switch (regs.ax) {
        0x05 => error.AccessDenied,
        0x06 => invalidHandle(file.handle),
        else => unreachable,
    } else regs.ax;
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
    const regs = dos.int21(.init(.{
        .ah = 0x42,
        .al = @intFromEnum(offset),
        .bx = file.handle,
        .cx = @as(u16, @truncate(raw_offset >> 16)),
        .dx = @as(u16, @truncate(raw_offset)),
    }));
    return if (regs.flags.carry) switch (regs.ax) {
        0x01 => unreachable, // Bad move method
        0x06 => invalidHandle(file.handle),
        else => unreachable,
    } else @as(u32, regs.dx) << 16 | regs.ax;
}

// https://www.ctyme.com/intr/rb-3170.htm
// https://archive.org/details/microsoftmsdospr0000unse/page/390
pub fn commit(file: File) void {
    const regs = dos.int21(.init(.{
        .ah = 0x68,
        .bx = file.handle,
    }));
    if (regs.flags.carry) switch (regs.ax) {
        0x06 => invalidHandle(file.handle),
        // TODO: Error codes for this function are not well-documented.
        else => |n| panic("unexpected DOS error code: 0x{x}", .{n}),
    };
}

fn invalidHandle(handle: Handle) noreturn {
    panic("invalid handle: {}", .{handle});
}
