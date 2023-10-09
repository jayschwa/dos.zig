const std = @import("std");

pub const FarPtr = extern struct {
    offset: usize = 0,
    segment: u16,

    pub fn read(self: FarPtr, buffer: []u8) void {
        _ = asm volatile (
            \\ push %%ds
            \\ lds (%[far_ptr]), %%esi
            \\ cld
            \\ rep movsb %%ds:(%%esi), %%es:(%%edi)
            \\ pop %%ds
            : [_] "=&{esi}" (-> usize),
            : [far_ptr] "r" (&self),
              [_] "{ecx}" (buffer.len),
              [_] "{edi}" (buffer.ptr),
            : "cc", "ecx", "edi", "memory"
        );
    }

    pub fn write(self: FarPtr, bytes: []const u8) void {
        _ = asm volatile (
            \\ push %%es
            \\ les (%[far_ptr]), %%edi
            \\ cld
            \\ rep movsb %%ds:(%%esi), %%es:(%%edi)
            \\ pop %%es
            : [_] "=&{edi}" (-> usize),
            : [far_ptr] "r" (&self),
              [_] "{ecx}" (bytes.len),
              [_] "{esi}" (bytes.ptr),
            : "cc", "ecx", "esi", "memory"
        );
    }

    pub const Reader = std.io.Reader(*FarPtr, error{}, readForReader);
    pub const Writer = std.io.Writer(*FarPtr, error{}, writeForWriter);

    pub fn reader(self: *FarPtr) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *FarPtr) Writer {
        return .{ .context = self };
    }

    fn readForReader(self: *FarPtr, buffer: []u8) !usize {
        self.read(buffer);
        self.offset += buffer.len;
        return buffer.len;
    }

    fn writeForWriter(self: *FarPtr, bytes: []const u8) !usize {
        self.write(bytes);
        self.offset += bytes.len;
        return bytes.len;
    }
};
