const root = @import("root");
const std = @import("std");
const panic = std.debug.panic;

const dpmi = @import("dpmi.zig");
const Segment = dpmi.Segment;
const FarPtr = @import("far_ptr.zig").FarPtr;
const system = @import("system.zig");

comptime {
    if (@hasDecl(root, "main")) @export(_start, .{ .name = "_start" });
}

// Initial stack pointer set by the linker script.
extern const _stack_ptr: opaque {};

fn _start() callconv(.Naked) noreturn {
    // Use the data segment to initialize the extended and stack segments.
    asm volatile (
        \\ mov %%ds, %%dx
        \\ mov %%dx, %%es
        \\ mov %%dx, %%ss
        :
        : [_] "{esp}" (&_stack_ptr),
        : "dx", "ds", "es", "ss"
    );

    asm volatile (
        \\ jmp %[start:P]
        :
        : [start] "X" (&start),
    );
}

fn start() noreturn {
    // Initialize transfer buffer from stub info.
    var stub_info_ptr = Segment.fromRegister(.fs).farPtr();
    const stub_info = stub_info_ptr.reader().readStruct(StubInfo) catch unreachable;

    system.transfer_buffer = .{
        .protected_mode_segment = .{
            .selector = stub_info.ds_selector,
        },
        .real_mode_segment = stub_info.ds_segment,
        .len = stub_info.min_keep,
    };

    self_mem_handle = stub_info.mem_handle;
    self_mem_size = stub_info.initial_size;

    const allocator: std.mem.Allocator = .{
        .ptr = undefined,
        .vtable = &std.heap.SbrkAllocator(sbrk).vtable,
    };

    for (0..8) |i| {
        const size = @as(usize, 1) << @intCast(i);
        std.debug.print("Alloc: {X}\r\n", .{size});
        const buf = allocator.alloc(u8, size) catch @panic("allocator failed");
        std.debug.print("New addr: {X}\r\n", .{@intFromPtr(buf.ptr)});
        @memset(buf, 0);
    }

    std.os.exit(std.start.callMain());
}

const StubInfo = extern struct {
    magic: [16]u8,
    size: u16, // Number of bytes in structure.
    min_stack: u32, // Minimum amount of DPMI stack space.
    mem_handle: u32, // DPMI memory block handle.
    initial_size: u32, // Size of initial segment.
    min_keep: u16, // Amount of automatic real-mode buffer.
    ds_selector: u16, // DS selector (used for transfer buffer).
    ds_segment: u16, // DS segment (used for simulated calls).
    psp_selector: u16, // Program segment prefix selector.
    cs_selector: u16, // To be freed.
    env_size: u16, // Number of bytes in environment.
    basename: [8]u8, // Base name of executable.
    argv0: [16]u8, // Used only by the application.
    dpmi_server: [16]u8, // Not used by CWSDSTUB.
};

var self_mem_handle: usize = undefined;
var self_mem_size: usize = undefined;
var far_resize_self: ?FarPtr = null;

pub fn sbrk(increment: usize) usize {
    if (increment != 0) {
        // FIXME: Check for overflow.
        const new_size = self_mem_size + increment;
        call_resize_self(new_size) catch @panic("sbrk failed");
        defer self_mem_size = new_size;
        return self_mem_size;
    }
    return self_mem_size;
}

fn call_resize_self(size: usize) !void {
    std.debug.print("Resize self to {X} bytes\r\n", .{size});

    if (far_resize_self == null) {
        const len = @intFromPtr(&resize_self_end) - @intFromPtr(&resize_self);
        const resize_self_data = @as([*]u8, @ptrCast(&resize_self))[0..len];
        const block = try dpmi.MemoryBlock.create(resize_self_data.len);
        const segment = block.createSegment(.{ .type = .data, .flags = .{ .data = .{} } });
        segment.write(resize_self_data);
        segment.setAccessRights(.{ .type = .code, .flags = .{ .code = .{} } });
        far_resize_self = segment.farPtr();
    }

    var addr_hi: u16 = undefined;
    var addr_lo: u16 = undefined;
    var mem_handle_hi: u16 = undefined;
    var mem_handle_lo: u16 = undefined;

    const error_code = asm volatile ("lcall *(%[func])"
        : [_] "={ax}" (-> u16),
          [_] "={bx}" (addr_hi),
          [_] "={cx}" (addr_lo),
          [_] "={si}" (mem_handle_hi),
          [_] "={di}" (mem_handle_lo),
        : [func] "r" (&far_resize_self.?),
          [_] "{ax}" (system.transfer_buffer.protected_mode_segment.selector),
          [_] "{bx}" (@as(u16, @truncate(size >> 16))),
          [_] "{cx}" (@as(u16, @truncate(size))),
          [_] "{si}" (@as(u16, @truncate(self_mem_handle >> 16))),
          [_] "{di}" (@as(u16, @truncate(self_mem_handle))),
        : "cc"
    );

    if (error_code != 0) return switch (error_code) {
        0x503 => error.OutOfMemory,
        0x8012 => error.LinearMemoryUnavailable,
        0x8013 => error.PhysicalMemoryUnavailable,
        0x8014 => error.BackingStoreUnavailable,
        0x8016 => error.HandleUnavailable,
        0x8021 => error.BadSize,
        0x8023 => error.BadMemoryHandle,
        else => |err| panic(@src().fn_name ++ ": unexpected error code: {x}", .{err}),
    };

    self_mem_handle = (@as(u32, mem_handle_hi) << 16) | mem_handle_lo;
    Segment.fromRegister(.ds).setLimit(size - 1);
}

comptime {
    asm (@embedFile("hello.s"));
}

extern var resize_self: opaque {};
extern var resize_self_end: opaque {};
