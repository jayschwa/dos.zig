pub const FarPtr = packed struct {
    offset: usize = 0,
    segment: u16,

    pub fn add(self: FarPtr, offset: usize) FarPtr {
        return .{
            .segment = self.segment,
            .offset = self.offset + offset,
        };
    }

    pub fn fill(self: FarPtr, value: u8, count: usize) void {
        asm volatile (
            \\ cld
            \\ push %%es
            \\ lesl (%[far_ptr]), %%edi
            \\ rep stosb %%al, %%es:(%%edi)
            \\ pop %%es
            : // No outputs
            : [far_ptr] "r" (&self),
              [_] "{al}" (value),
              [_] "{ecx}" (count)
            : "cc", "ecx", "edi", "memory"
        );
    }

    pub fn read(self: FarPtr, buffer: []u8) void {
        asm volatile (
            \\ cld
            \\ push %%fs
            \\ lfsl (%[far_ptr]), %%esi
            \\ rep movsb %%fs:(%%esi), %%es:(%%edi)
            \\ pop %%fs
            : // No outputs
            : [far_ptr] "r" (&self),
              [_] "{ecx}" (buffer.len),
              [_] "{edi}" (buffer.ptr)
            : "cc", "ecx", "edi", "esi", "memory"
        );
    }

    pub fn write(self: FarPtr, bytes: []const u8) void {
        asm volatile (
            \\ cld
            \\ push %%es
            \\ lesl (%[far_ptr]), %%edi
            \\ rep movsb %%ds:(%%esi), %%es:(%%edi)
            \\ pop %%es
            : // No outputs
            : [far_ptr] "r" (&self),
              [_] "{ecx}" (bytes.len),
              [_] "{esi}" (bytes.ptr)
            : "cc", "ecx", "edi", "esi", "memory"
        );
    }
};
