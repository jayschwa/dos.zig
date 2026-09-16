pub const Target = union(enum) {
    interrupt: u8,
    procedure: Procedure,
};

pub const Procedure = struct {
    address: Address,
    return_frame: enum { far, interrupt },

    pub const Address = struct { cs: u16, ip: u16 };
};

pub const Registers = struct {
    eax: u32 = 0,
    ebx: u32 = 0,
    ecx: u32 = 0,
    edx: u32 = 0,
    esi: u32 = 0,
    edi: u32 = 0,
    ebp: u32 = 0,
    flags: u16 = 0,
    es: u16 = 0,
    ds: u16 = 0,
    fs: u16 = 0,
    gs: u16 = 0,

    pub fn ax(regs: Registers) u16 {
        return @truncate(regs.eax);
    }
};

pub const Stack = struct {
    location: union(enum) { host, address: Address } = .host,
    copy_words: u16 = 0,

    pub const Address = struct { ss: u16, sp: u16 };
};

pub const CallRealModeError = error{
    LinearMemoryUnavailable,
    PhysicalMemoryUnavailable,
    BackingStoreUnavailable,
    StackCopyWouldOverflow,
};

pub fn callRealMode(
    target: Target,
    registers: Registers,
    stack: Stack,
) CallRealModeError!Registers {
    const dpmi_function: u16 = switch (target) {
        .interrupt => 0x300,
        .procedure => |proc| switch (proc.return_frame) {
            .far => 0x301,
            .interrupt => 0x302,
        },
    };
    const real_interrupt: u8 = switch (target) {
        .interrupt => |n| n,
        .procedure => 0,
    };
    const real_proc_addr: Procedure.Address = switch (target) {
        .interrupt => .{ .cs = 0, .ip = 0 },
        .procedure => |proc| proc.address,
    };
    const stack_addr: Stack.Address = switch (stack.location) {
        .host => .{ .ss = 0, .sp = 0 },
        .address => |address| address,
    };
    var call_data: CallData = .{
        .eax = registers.eax,
        .ebx = registers.ebx,
        .ecx = registers.ecx,
        .edx = registers.edx,
        .esi = registers.esi,
        .edi = registers.edi,
        .ebp = registers.ebp,
        .flags = registers.flags,
        .es = registers.es,
        .ds = registers.ds,
        .fs = registers.fs,
        .gs = registers.gs,
        .cs = real_proc_addr.cs,
        .ip = real_proc_addr.ip,
        .ss = stack_addr.ss,
        .sp = stack_addr.sp,
    };
    var errno: u16 = undefined;
    const flags = asm volatile (
        \\ int $0x31
        \\ pushfw
        \\ popw %[flags]
        : [flags] "=r" (-> u16),
          [errno] "={ax}" (errno),
        : [_] "{ax}" (dpmi_function),
          [_] "{bh}" (0),
          [_] "{bl}" (real_interrupt),
          [_] "{cx}" (stack.copy_words),
          [_] "{edi}" (&call_data),
        : .{ .cc = true, .memory = true });
    return if (flags & 1 != 0) switch (errno) {
        0x8012 => error.LinearMemoryUnavailable,
        0x8013 => error.PhysicalMemoryUnavailable,
        0x8014 => error.BackingStoreUnavailable,
        0x8021 => error.StackCopyWouldOverflow,
        else => unreachable,
    } else .{
        .eax = call_data.eax,
        .ebx = call_data.ebx,
        .ecx = call_data.ecx,
        .edx = call_data.edx,
        .esi = call_data.esi,
        .edi = call_data.edi,
        .ebp = call_data.ebp,
        .flags = call_data.flags,
        .es = call_data.es,
        .ds = call_data.ds,
        .fs = call_data.fs,
        .gs = call_data.gs,
    };
}

const CallData = extern struct {
    edi: u32,
    esi: u32,
    ebp: u32,
    reserved: u32 = 0,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,
    flags: u16,
    es: u16,
    ds: u16,
    fs: u16,
    gs: u16,
    ip: u16,
    cs: u16,
    sp: u16,
    ss: u16,
};
