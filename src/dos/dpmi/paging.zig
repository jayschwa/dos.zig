pub fn getPageSize() usize {
    var high: u16 = undefined;
    var low: u16 = undefined;
    // TODO: Check carry flag for error.
    asm volatile ("int $0x31"
        : [_] "={bx}" (high),
          [_] "={cx}" (low),
        : [func] "{ax}" (@as(u16, 0x604)),
        : "cc"
    );
    return @as(usize, high) << 16 | low;
}
