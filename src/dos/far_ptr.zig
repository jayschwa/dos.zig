const std = @import("std");

pub const FarPtr = packed struct {
    offset: usize = 0,
    segment: u16,

    pub fn read(self: *FarPtr, buffer: []u8) void {
        self.offset = asm volatile (
            \\ cld
            \\ push %%fs
            \\ lfsl (%[far_ptr]), %%esi
            \\ rep movsb %%fs:(%%esi), %%es:(%%edi)
            \\ pop %%fs
            : [_] "={esi}" (-> usize)
            : [far_ptr] "r" (self),
              [_] "{ecx}" (buffer.len),
              [_] "{edi}" (buffer.ptr)
            : "cc", "ecx", "edi", "memory"
        );
    }

    pub fn write(self: *FarPtr, bytes: []const u8) void {
        self.offset = asm volatile (
            \\ cld
            \\ push %%es
            \\ lesl (%[far_ptr]), %%edi
            \\ rep movsb %%ds:(%%esi), %%es:(%%edi)
            \\ pop %%es
            : [_] "={edi}" (-> usize)
            : [far_ptr] "r" (self),
              [_] "{ecx}" (bytes.len),
              [_] "{esi}" (bytes.ptr)
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
        return buffer.len;
    }

    fn writeForWriter(self: *FarPtr, bytes: []const u8) !usize {
        self.write(bytes);
        return bytes.len;
    }
};
