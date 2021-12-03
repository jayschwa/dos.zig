const std = @import("std");
const panic = std.debug.panic;

pub const RealModeRegisters = extern struct {
    edi: u32 = undefined,
    esi: u32 = undefined,
    ebp: u32 = undefined,
    reserved: u32 = 0,
    ebx: u32 = undefined,
    edx: u32 = undefined,
    ecx: u32 = undefined,
    eax: u32 = undefined,
    flags: u16 = undefined,
    es: u16 = undefined,
    ds: u16 = undefined,
    fs: u16 = undefined,
    gs: u16 = undefined,
    ip: u16 = undefined,
    cs: u16 = undefined,
    sp: u16 = 0,
    ss: u16 = 0,

    pub fn ax(regs: RealModeRegisters) u16 {
        return @truncate(u16, regs.eax);
    }
};

pub fn simulateInterrupt(interrupt: u8, registers: *RealModeRegisters) void {
    simulateInterruptWithStack(interrupt, registers, 0) catch |err| {
        // All errors are stack-related and thus unexpected.
        panic(@src().fn_name ++ " failed with unexpected error: {s}", .{@errorName(err)});
    };
}

pub fn simulateInterruptWithStack(interrupt: u8, registers: *RealModeRegisters, stack_words: u16) !void {
    var errno: u16 = undefined;
    const flags = asm volatile (
        \\ int $0x31
        \\ pushfw
        \\ popw %[flags]
        : [flags] "=r" (-> u16),
          [errno] "={ax}" (errno),
        : [_] "{ax}" (@as(u16, 0x300)),
          [_] "{bx}" (interrupt),
          [_] "{cx}" (stack_words),
          [_] "{edi}" (registers),
        : "cc", "memory"
    );
    if (flags & 1 != 0)
        return switch (errno) {
            0x8012 => error.LinearMemoryUnavailable,
            0x8013 => error.PhysicalMemoryUnavailable,
            0x8014 => error.BackingStoreUnavailable,
            0x8021 => error.StackTooLarge,
            else => panic(@src().fn_name ++ " failed with unexpected error code: {x}", .{errno}),
        };
}
