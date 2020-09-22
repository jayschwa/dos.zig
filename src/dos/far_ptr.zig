const std = @import("std");

pub const FarPtr = packed struct {
    offset: usize = 0,
    segment: u16,

    pub const Reader = std.io.Reader(*FarPtr, error{}, read);
    pub const Writer = std.io.Writer(*FarPtr, error{}, write);

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

    pub fn reader(self: *FarPtr) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *FarPtr) Writer {
        return .{ .context = self };
    }

    fn read(self: *FarPtr, buffer: []u8) !usize {
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
        return buffer.len;
    }

    fn write(self: *FarPtr, bytes: []const u8) !usize {
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
        return bytes.len;
    }
};
