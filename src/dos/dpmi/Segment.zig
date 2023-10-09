// TODO: Enforce descriptor usage rules with the type system.
//
// See: http://www.delorie.com/djgpp/doc/dpmi/descriptor-rules.html

const FarPtr = @import("../far_ptr.zig").FarPtr;

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

pub const Type = enum {
    code,
    data,
};

pub fn setAccessRights(self: Segment, seg_type: Segment.Type) void {
    // TODO: Represent rights with packed struct?
    // TODO: Is hardcoding the privilege level bad?
    const rights: u16 = switch (seg_type) {
        .code => 0xc0fb, // 32-bit, ring 3, big, code, non-conforming, readable
        .data => 0xc0f3, // 32-bit, ring 3, big, data, R/W, expand-up
    };
    // TODO: Check carry flag for error.
    asm volatile ("int $0x31"
        : // No outputs
        : [func] "{ax}" (@as(u16, 9)),
          [_] "{bx}" (self.selector),
          [_] "{cx}" (rights),
    );
}

pub fn farPtr(self: Segment) FarPtr {
    return .{ .segment = self.selector };
}

pub fn read(self: Segment, buffer: []u8) void {
    return self.farPtr().read(buffer);
}

pub fn write(self: Segment, bytes: []const u8) void {
    return self.farPtr().write(bytes);
}