const std = @import("std");
const FarPtr = @import("../far_ptr.zig").FarPtr;
const Segment = @import("Segment.zig");

/// DosMemBlock represents an allocated block of memory that resides below the
/// 1 MiB address in physical memory and is accessible to DOS.
pub const DosMemBlock = struct {
    protected_mode_segment: Segment,
    real_mode_segment: u16,
    len: usize,

    pub fn alloc(size: u20) !DosMemBlock {
        const aligned_size = std.mem.alignForwardGeneric(@TypeOf(size), size, 16);
        var protected_selector: u16 = 0;
        var real_segment: u16 = 0;
        const flags = asm volatile (
            \\ int $0x31
            \\ pushfw
            \\ popw %[flags]
            : [flags] "=r" (-> u16),
              [_] "={ax}" (real_segment),
              [_] "={dx}" (protected_selector),
            : [_] "{ax}" (@as(u16, 0x100)),
              [_] "{bx}" (aligned_size / 16),
            : "cc"
        );
        // TODO: Better error handling.
        if (flags & 1 != 0) return error.DpmiAllocError;
        return DosMemBlock{
            .protected_mode_segment = .{ .selector = protected_selector },
            .real_mode_segment = real_segment,
            .len = aligned_size,
        };
    }

    pub fn read(self: DosMemBlock, buffer: []u8) void {
        return self.protected_mode_segment.read(buffer);
    }

    pub fn write(self: DosMemBlock, bytes: []const u8) void {
        return self.protected_mode_segment.write(bytes);
    }
};

/// ExtMemBlock represents an allocated block of extended memory that resides
/// above the 1 MiB address in physical memory.
pub const ExtMemBlock = struct {
    addr: usize,
    len: usize,
    handle: usize,

    pub fn alloc(size: usize) !ExtMemBlock {
        var bx: u16 = undefined;
        var cx: u16 = undefined;
        var si: u16 = undefined;
        var di: u16 = undefined;

        const flags = asm volatile (
            \\ int $0x31
            \\ pushfw
            \\ popw %[flags]
            : [flags] "=r" (-> u16),
              [_] "={bx}" (bx),
              [_] "={cx}" (cx),
              [_] "={si}" (si),
              [_] "={di}" (di),
            : [_] "{ax}" (@as(u16, 0x501)),
              [_] "{bx}" (@as(u16, @truncate(size >> 16))),
              [_] "{cx}" (@as(u16, @truncate(size))),
        );
        // TODO: Better error handling.
        if (flags & 1 != 0) return error.DpmiAllocError;
        return ExtMemBlock{
            .addr = @as(usize, bx) << 16 | cx,
            .len = size,
            .handle = @as(usize, si) << 16 | di,
        };
    }

    pub fn createSegment(self: ExtMemBlock, seg_type: Segment.Type) Segment {
        const segment = Segment.alloc();
        segment.setBaseAddress(self.addr);
        segment.setAccessRights(seg_type);
        segment.setLimit(self.len - 1);
        return segment;
    }
};
