const real_mode = @import("../real_mode.zig");
const FarPtr = real_mode.FarPtr;

pub fn enterProtectedMode() !void {
    const entry_point = try getEntryPoint();
    var data_segment: u16 = 0;
    if (entry_point.paragraphs_required > 0) {
        data_segment = try real_mode.malloc(entry_point.paragraphs_required);
        errdefer real_mode.free(data_segment);
    }
    const flags = asm volatile (
        \\ mov %[data_segment], %%es
        \\ lcall *%[func]
        \\ lahf
        : [_] "={ah}" (-> u8)
        : [func] "m" (@bitCast(u32, entry_point.function)),
          [_] "{ax}" (@as(u16, 1)), // 32-bit
          [data_segment] "m" (data_segment)
        : "cc", "cs", "ds", "es", "ss"
    );
    if (flags & 1 != 0) {
        return error.ProtectedModeSwitchFailed;
    }
    asm volatile (
        \\ push %%ds
        \\ pop %%es
    );
}

const EntryPoint = struct {
    function: FarPtr,
    paragraphs_required: u16,
    dpmi_version: Version,
};

const Version = packed struct {
    major: u8,
    minor: u8,
};

pub fn getEntryPoint() !EntryPoint {
    var flags: u16 = undefined;
    var dpmi_version: Version = undefined;
    var paragraphs_required: u16 = undefined;
    var segment: u16 = undefined;
    var offset: u16 = undefined;

    const ret = asm volatile (
        \\ push %%es
        \\ int $0x2f
        \\ mov %%es, %[segment]
        \\ pop %%es
        : [ret] "={ax}" (-> u16),
          [_] "={bx}" (flags),
          [_] "={dx}" (dpmi_version),
          [_] "={si}" (paragraphs_required),
          [segment] "=r" (segment),
          [_] "={di}" (offset)
        : [_] "{ax}" (@as(u16, 0x1687))
        : "es"
    );
    if (ret != 0) return error.NoDpmi;
    if (flags & 1 == 0) return error.No32BitSupport;

    return EntryPoint{
        .function = .{ .offset = offset, .segment = segment },
        .paragraphs_required = paragraphs_required,
        .dpmi_version = dpmi_version,
    };
}
