//! MemoryBlock represents an allocated block of extended memory that resides
//! above the 1 MiB address in physical memory.

const Self = @This();
const FarPtr = @import("../far_ptr.zig").FarPtr;
const Segment = @import("Segment.zig");

handle: usize,
addr: usize,
len: usize,

pub fn create(size: usize) !Self {
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

    return .{
        .handle = @as(usize, si) << 16 | di,
        .addr = @as(usize, bx) << 16 | cx,
        .len = size,
    };
}

pub fn createSegment(self: Self, rights: Segment.AccessRights) Segment {
    const segment = Segment.create();
    errdefer segment.destroy();

    segment.setBaseAddress(self.addr);
    segment.setAccessRights(rights);
    segment.setLimit(self.len - 1);

    return segment;
}
