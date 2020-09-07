pub const fd_t = u16;
pub const mode_t = u8;
pub const off_t = i32;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const SEEK_SET = 0;
pub const SEEK_CUR = 1;
pub const SEEK_END = 2;

// Copy in some shit to shutup the compiler.
pub usingnamespace @import("errno.zig");
