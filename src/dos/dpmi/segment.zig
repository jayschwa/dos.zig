pub const Segment = struct {
    selector: u16,

    pub const Type = enum {
        Code,
        Data,
    };

    pub fn alloc() Segment {
        // TODO: Check carry flag for error.
        const selector = asm volatile ("int $0x31"
            : [_] "={ax}" (-> u16)
            : [func] "{ax}" (@as(u16, 0)),
              [_] "{cx}" (@as(u16, 1))
        );
        return Segment{ .selector = selector };
    }

    pub fn getBaseAddress(self: Segment) usize {
        var addr_high: u16 = undefined;
        var addr_low: u16 = undefined;
        // TODO: Check carry flag for error.
        asm ("int $0x31"
            : [_] "={cx}" (addr_high),
              [_] "={dx}" (addr_low)
            : [func] "{ax}" (@as(u16, 6)),
              [_] "{bx}" (self.selector)
        );
        return @as(usize, addr_high) << 16 | addr_low;
    }

    pub fn setAccessRights(self: Segment, seg_type: Segment.Type) void {
        // TODO: Represent rights with packed struct?
        // TODO: Is hardcoding the privilege level bad?
        const rights: u16 = switch (seg_type) {
            .Code => 0xc0fb, // 32-bit, ring 3, big, code, non-conforming, readable
            .Data => 0xc0f3, // 32-bit, ring 3, big, data, R/W, expand-up
        };
        // TODO: Check carry flag for error.
        asm volatile ("int $0x31"
            : // No outputs
            : [func] "{ax}" (@as(u16, 9)),
              [_] "{bx}" (self.selector),
              [_] "{cx}" (rights)
        );
    }

    pub fn setBaseAddress(self: Segment, addr: usize) void {
        // TODO: Check carry flag for error.
        asm volatile ("int $0x31"
            : // No outputs
            : [func] "{ax}" (@as(u16, 7)),
              [_] "{bx}" (self.selector),
              [_] "{cx}" (@truncate(u16, addr >> 16)),
              [_] "{dx}" (@truncate(u16, addr))
        );
    }

    pub fn setLimit(self: Segment, limit: usize) void {
        // TODO: Check carry flag for error.
        // TODO: Check that limit meets alignment requirements.
        asm volatile ("int $0x31"
            : // No outputs
            : [func] "{ax}" (@as(u16, 8)),
              [_] "{bx}" (self.selector),
              [_] "{cx}" (@truncate(u16, limit >> 16)),
              [_] "{dx}" (@truncate(u16, limit))
        );
    }

    /// Copy bytes from segment starting at offset to buffer.
    pub fn readFrom(self: Segment, buffer: []u8, offset: usize) void {
        // TODO: Optimize by copying 32 bits at a time.
        asm volatile (
            \\ push %%es
            \\ push %%ds
            \\ pop %%es
            \\ mov %[selector], %%ds
            \\ cld
            \\ rep movsb (%%esi), %%es:(%%edi)
            \\ push %%es
            \\ pop %%ds
            \\ pop %%es
            : // No outputs
            : [selector] "r" (self.selector),
              [_] "{ecx}" (buffer.len),
              [_] "{edi}" (buffer.ptr),
              [_] "{esi}" (offset)
            : "cc", "ecx", "edi", "esi", "memory"
        );
    }

    /// Copy bytes from buffer to segment starting at offset.
    pub fn writeAt(self: Segment, bytes: []const u8, offset: usize) void {
        // TODO: Optimize by copying 32 bits at a time.
        asm volatile (
            \\ push %%es
            \\ mov %[selector], %%es
            \\ cld
            \\ rep movsb (%%esi), %%es:(%%edi)
            \\ pop %%es
            : // No outputs
            : [selector] "r" (self.selector),
              [_] "{ecx}" (bytes.len),
              [_] "{edi}" (offset),
              [_] "{esi}" (bytes.ptr)
            : "cc", "ecx", "edi", "esi", "memory"
        );
    }

    pub fn zeroAt(self: Segment, offset: usize, len: usize) void {
        // TODO: Optimize by writing 32 bits at a time.
        asm volatile (
            \\ push %%es
            \\ mov %[selector], %%es
            \\ cld
            \\ rep stosb %%al, %%es:(%%edi)
            \\ pop %%es
            : // No outputs
            : [selector] "r" (self.selector),
              [_] "{ecx}" (len),
              [_] "{edi}" (offset),
              [_] "{al}" (@as(u8, 0))
            : "cc", "ecx", "edi", "memory"
        );
    }
};
