pub const FarPtr = struct {
    segment: u16,
    offset: usize = 0,

    pub fn add(self: FarPtr, offset: usize) FarPtr {
        return .{
            .segment = self.segment,
            .offset = self.offset + offset,
        };
    }

    pub fn fill(self: FarPtr, value: u8, count: usize) void {
        asm volatile (
            \\ push %%es
            \\ mov %[segment], %%es
            \\ cld
            \\ rep stosb %%al, %%es:(%%edi)
            \\ pop %%es
            : // No outputs
            : [segment] "r" (self.segment),
              [_] "{al}" (value),
              [_] "{ecx}" (count),
              [_] "{edi}" (self.offset)
            : "cc", "ecx", "edi", "memory"
        );
    }

    pub fn read(self: FarPtr, buffer: []u8) void {
        asm volatile (
            \\ push %%es
            \\ push %%ds
            \\ pop %%es
            \\ mov %[segment], %%ds
            \\ cld
            \\ rep movsb (%%esi), %%es:(%%edi)
            \\ push %%es
            \\ pop %%ds
            \\ pop %%es
            : // No outputs
            : [segment] "r" (self.segment),
              [_] "{ecx}" (buffer.len),
              [_] "{edi}" (buffer.ptr),
              [_] "{esi}" (self.offset)
            : "cc", "ecx", "edi", "esi", "memory"
        );
    }

    pub fn write(self: FarPtr, bytes: []const u8) void {
        asm volatile (
            \\ push %%es
            \\ mov %[segment], %%es
            \\ cld
            \\ rep movsb (%%esi), %%es:(%%edi)
            \\ pop %%es
            : // No outputs
            : [segment] "r" (self.segment),
              [_] "{ecx}" (bytes.len),
              [_] "{edi}" (self.offset),
              [_] "{esi}" (bytes.ptr)
            : "cc", "ecx", "edi", "esi", "memory"
        );
    }
};
