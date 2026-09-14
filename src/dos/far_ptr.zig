pub const FarPtr = packed struct {
    offset: usize = 0,
    segment: u16,

    pub fn read(self: FarPtr, buffer: []u8) void {
        _ = asm volatile (
            \\ push %%ds
            \\ lds (%[far_ptr]), %%esi
            \\ cld
            \\ rep movsb
            \\ pop %%ds
            : [_] "=&{esi}" (-> usize),
            : [far_ptr] "r" (&self),
              [_] "{ecx}" (buffer.len),
              [_] "{edi}" (buffer.ptr),
            : .{ .cc = true, .ecx = true, .edi = true, .memory = true });
    }

    pub fn write(self: FarPtr, bytes: []const u8) void {
        _ = asm volatile (
            \\ push %%es
            \\ les (%[far_ptr]), %%edi
            \\ cld
            \\ rep movsb
            \\ pop %%es
            : [_] "=&{edi}" (-> usize),
            : [far_ptr] "r" (&self),
              [_] "{ecx}" (bytes.len),
              [_] "{esi}" (bytes.ptr),
            : .{ .cc = true, .ecx = true, .esi = true, .memory = true });
    }

    pub fn readStruct(self: FarPtr, T: type) T {
        var result: T = undefined;
        self.read(@ptrCast(&result));
        return result;
    }
};
