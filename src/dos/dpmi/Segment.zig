// TODO: Enforce descriptor usage rules with the type system.
//
// See: http://www.delorie.com/djgpp/doc/dpmi/descriptor-rules.html

const std = @import("std");
const expectEqual = std.testing.expectEqual;

selector: u16,

const Segment = @This();

pub fn alloc() Segment {
    // TODO: Check carry flag for error.
    const selector = asm volatile ("int $0x31"
        : [_] "={ax}" (-> u16),
        : [func] "{ax}" (@as(u16, 0)),
          [_] "{cx}" (@as(u16, 1)),
    );
    return Segment{ .selector = selector };
}

pub const Register = enum {
    cs, // Code
    ss, // Stack
    ds, // Data
    es, // Extra
    fs,
    gs,
};

pub fn fromRegister(comptime r: Register) Segment {
    return .{
        .selector = asm ("movw %%" ++ @tagName(r) ++ ", %[selector]"
            : [selector] "=r" (-> u16),
        ),
    };
}

pub fn getBaseAddress(self: Segment) usize {
    var addr_high: u16 = undefined;
    var addr_low: u16 = undefined;
    // TODO: Check carry flag for error.
    asm ("int $0x31"
        : [_] "={cx}" (addr_high),
          [_] "={dx}" (addr_low),
        : [func] "{ax}" (@as(u16, 6)),
          [_] "{bx}" (self.selector),
    );
    return @as(usize, addr_high) << 16 | addr_low;
}

pub fn setBaseAddress(self: Segment, addr: usize) void {
    // TODO: Check carry flag for error.
    asm volatile ("int $0x31"
        : // No outputs
        : [func] "{ax}" (@as(u16, 7)),
          [_] "{bx}" (self.selector),
          [_] "{cx}" (@as(u16, @truncate(addr >> 16))),
          [_] "{dx}" (@as(u16, @truncate(addr))),
    );
}

pub fn getLimit(self: Segment) usize {
    return asm ("lsl %[selector], %[ret]"
        : [ret] "=r" (-> usize),
        : [selector] "rm" (self.selector),
    );
}

pub fn setLimit(self: Segment, limit: usize) void {
    // TODO: Check carry flag for error.
    // TODO: Check that limit meets alignment requirements.
    asm volatile ("int $0x31"
        : // No outputs
        : [func] "{ax}" (@as(u16, 8)),
          [_] "{bx}" (self.selector),
          [_] "{cx}" (@as(u16, @truncate(limit >> 16))),
          [_] "{dx}" (@as(u16, @truncate(limit))),
    );
}

pub const Type = enum(u2) {
    system = 0b00,
    data = 0b10,
    code = 0b11,
};

pub const AccessRights = packed struct {
    accessed: bool = true,
    flags: packed union {
        code: packed struct {
            readable: bool = true,
            conforming: bool = false,
        },
        data: packed struct {
            writeable: bool,
            expand: enum(u1) { up = 0, down = 1 } = .up,
        },
    },
    type: Type,
    privilege_level: u2 = 3,
    present: bool = true,
    limit: u4 = 0,
    user_bit: u1 = 0,
    reserved: u1 = 0,
    size: enum(u1) { @"16_bit" = 0, @"32_bit" = 1 } = .@"32_bit",
    granularity: enum(u1) { byte = 0, page = 1 } = .byte,
};

pub fn getAccessRights(self: Segment) AccessRights {
    // TODO: Check zero flag for error.
    const bits = asm ("lar %[selector], %[rights]"
        : [rights] "=r" (-> u32),
        : [selector] "rm" (self.selector),
    );
    return @bitCast(@as(u16, @truncate(bits >> 8)));
}

pub fn setAccessRights(self: Segment, rights: AccessRights) void {
    // TODO: Check carry flag for error.
    asm volatile ("int $0x31"
        : // No outputs
        : [func] "{ax}" (@as(u16, 9)),
          [_] "{bx}" (self.selector),
          [_] "{cx}" (rights),
    );
}

test "AccessRights" {
    const code: AccessRights = .{
        .type = .code,
        .flags = .{ .code = .{} },
    };
    try expectEqual(0x40fb, @as(u16, @bitCast(code)));

    const ro_data: AccessRights = .{
        .type = .data,
        .flags = .{ .data = .{ .writeable = false } },
    };
    try expectEqual(0x40f1, @as(u16, @bitCast(ro_data)));

    const rw_data: AccessRights = .{
        .type = .data,
        .flags = .{ .data = .{ .writeable = true } },
        .granularity = .page,
    };
    try expectEqual(0xc0f3, @as(u16, @bitCast(rw_data)));
}

const FarPtr = @import("../far_ptr.zig").FarPtr;

pub fn farPtr(self: Segment) FarPtr {
    return .{ .segment = self.selector };
}

pub fn read(self: Segment, buffer: []u8) void {
    return self.farPtr().read(buffer);
}

pub fn write(self: Segment, bytes: []const u8) void {
    return self.farPtr().write(bytes);
}
