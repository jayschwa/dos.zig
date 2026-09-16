const std = @import("std");
const FieldEnum = std.meta.FieldEnum;
const fieldNames = std.meta.fieldNames;

pub const Target = union(enum) {
    interrupt: u8,
    procedure: Procedure,
};

pub const Procedure = struct {
    address: Address,
    return_frame: enum { far, interrupt },

    pub const Address = struct { cs: u16, ip: u16 };
};

pub const RegisterInput = struct {
    eax: u32 = 0,
    ebx: u32 = 0,
    ecx: u32 = 0,
    edx: u32 = 0,
    esi: u32 = 0,
    edi: u32 = 0,
    ebp: u32 = 0,
    ds: u16 = 0,
    es: u16 = 0,
    fs: u16 = 0,
    gs: u16 = 0,
    flags: Flags = .{},

    pub fn init(values: anytype) RegisterInput {
        const Values = @TypeOf(values);
        var regs: RegisterInput = .{};
        inline for (comptime fieldNames(Values)) |name| {
            const value = @field(values, name);
            if (@hasField(RegisterInput, name)) {
                @field(regs, name) = value;
            } else if (comptime findGroup(.word, name)) |group| {
                if (@hasField(Values, group.long)) registerConflict(name, group.long);
                @field(regs, group.long) = @as(u16, value);
            } else if (comptime findGroup(.msb, name)) |group| {
                if (@hasField(Values, group.long)) registerConflict(name, group.long);
                if (@hasField(Values, group.word)) registerConflict(name, group.word);
                @field(regs, group.long) |= @as(u16, @as(u8, value)) << 8;
            } else if (comptime findGroup(.lsb, name)) |group| {
                if (@hasField(Values, group.long)) registerConflict(name, group.long);
                if (@hasField(Values, group.word)) registerConflict(name, group.word);
                @field(regs, group.long) |= @as(u8, value);
            } else @compileError("unknown register: " ++ name);
        }
        return regs;
    }

    const Group = struct {
        long: []const u8,
        word: []const u8,
        msb: ?[]const u8 = null,
        lsb: ?[]const u8 = null,

        fn contains(group: Group, field: FieldEnum(Group), name: []const u8) bool {
            const opt_candidate: ?[]const u8 = @field(group, @tagName(field));
            return if (opt_candidate) |candidate| std.mem.eql(u8, candidate, name) else false;
        }
    };

    const groups = [_]Group{
        .{ .long = "eax", .word = "ax", .msb = "ah", .lsb = "al" },
        .{ .long = "ebx", .word = "bx", .msb = "bh", .lsb = "bl" },
        .{ .long = "ecx", .word = "cx", .msb = "ch", .lsb = "cl" },
        .{ .long = "edx", .word = "dx", .msb = "dh", .lsb = "dl" },
        .{ .long = "esi", .word = "si" },
        .{ .long = "edi", .word = "di" },
        .{ .long = "ebp", .word = "bp" },
    };

    fn findGroup(field: FieldEnum(Group), name: []const u8) ?Group {
        return for (groups) |group| {
            if (group.contains(field, name)) break group;
        } else null;
    }

    fn registerConflict(comptime left: []const u8, comptime right: []const u8) noreturn {
        @compileError("registers '" ++ left ++ "' and '" ++ right ++ "' cannot coexist");
    }
};

pub const RegisterOutput = struct {
    eax: u32,
    ax: u16,
    ah: u8,
    al: u8,
    ebx: u32,
    bx: u16,
    bh: u8,
    bl: u8,
    ecx: u32,
    cx: u16,
    ch: u8,
    cl: u8,
    edx: u32,
    dx: u16,
    dh: u8,
    dl: u8,
    esi: u32,
    si: u16,
    edi: u32,
    di: u16,
    ebp: u32,
    bp: u16,
    ds: u16,
    es: u16,
    fs: u16,
    gs: u16,
    flags: Flags,
};

pub const Flags = packed struct(u16) {
    carry: bool = false,
    _reserved_bit_1: u1 = 1,
    parity: bool = false,
    _reserved_bit_3: u1 = 0,
    aux_carry: bool = false,
    _reserved_bit_5: u1 = 0,
    zero: bool = false,
    sign: enum(u1) { positive = 0, negative = 1 } = .positive,
    trap: bool = false,
    interrupt: enum(u1) { disable = 0, enable = 1 } = .disable,
    direction: enum(u1) { up = 0, down = 1 } = .up,
    overflow: bool = false,
    io_privilege_level: u2 = 0,
    nested_task: bool = false,
    _reserved_bit_15: u1 = 0,
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
    registers: RegisterInput,
    stack: Stack,
) CallRealModeError!RegisterOutput {
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
        .ds = registers.ds,
        .es = registers.es,
        .fs = registers.fs,
        .gs = registers.gs,
        .flags = registers.flags,
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
        : [flags] "=r" (-> Flags),
          [errno] "={ax}" (errno),
        : [_] "{ax}" (dpmi_function),
          [_] "{bh}" (0),
          [_] "{bl}" (real_interrupt),
          [_] "{cx}" (stack.copy_words),
          [_] "{edi}" (&call_data),
        : .{ .cc = true, .memory = true });
    return if (flags.carry) switch (errno) {
        0x8012 => error.LinearMemoryUnavailable,
        0x8013 => error.PhysicalMemoryUnavailable,
        0x8014 => error.BackingStoreUnavailable,
        0x8021 => error.StackCopyWouldOverflow,
        else => unreachable,
    } else .{
        .eax = call_data.eax,
        .ax = @truncate(call_data.eax),
        .ah = @truncate(call_data.eax >> 8),
        .al = @truncate(call_data.eax),
        .ebx = call_data.ebx,
        .bx = @truncate(call_data.ebx),
        .bh = @truncate(call_data.ebx >> 8),
        .bl = @truncate(call_data.ebx),
        .ecx = call_data.ecx,
        .cx = @truncate(call_data.ecx),
        .ch = @truncate(call_data.ecx >> 8),
        .cl = @truncate(call_data.ecx),
        .edx = call_data.edx,
        .dx = @truncate(call_data.edx),
        .dh = @truncate(call_data.edx >> 8),
        .dl = @truncate(call_data.edx),
        .esi = call_data.esi,
        .si = @truncate(call_data.esi),
        .edi = call_data.edi,
        .di = @truncate(call_data.edi),
        .ebp = call_data.ebp,
        .bp = @truncate(call_data.ebp),
        .ds = call_data.ds,
        .es = call_data.es,
        .fs = call_data.fs,
        .gs = call_data.gs,
        .flags = call_data.flags,
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
    flags: Flags,
    es: u16,
    ds: u16,
    fs: u16,
    gs: u16,
    ip: u16,
    cs: u16,
    sp: u16,
    ss: u16,
};
