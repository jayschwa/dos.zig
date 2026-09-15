pub const RealModeRegisters = extern struct {
    edi: u32 = 0,
    esi: u32 = 0,
    ebp: u32 = 0,
    reserved: u32 = 0,
    ebx: u32 = 0,
    edx: u32 = 0,
    ecx: u32 = 0,
    eax: u32 = 0,
    flags: u16 = 0,
    es: u16 = 0,
    ds: u16 = 0,
    fs: u16 = 0,
    gs: u16 = 0,
    ip: u16 = 0,
    cs: u16 = 0,
    sp: u16 = 0,
    ss: u16 = 0,

    pub fn ax(regs: RealModeRegisters) u16 {
        return @truncate(regs.eax);
    }
};

pub fn simulateInterrupt(interrupt: u8, registers: *RealModeRegisters) void {
    simulateInterruptWithStack(interrupt, registers, 0) catch |err| switch (err) {
        error.LinearMemoryUnavailable,
        error.PhysicalMemoryUnavailable,
        error.BackingStoreUnavailable,
        error.StackTooLarge,
        => unreachable,
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
        : .{ .cc = true, .memory = true });
    if (flags & 1 != 0)
        return switch (errno) {
            0x8012 => error.LinearMemoryUnavailable,
            0x8013 => error.PhysicalMemoryUnavailable,
            0x8014 => error.BackingStoreUnavailable,
            0x8021 => error.StackTooLarge,
            else => unreachable,
        };
}
