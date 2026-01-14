pub const RealModeRegisters = @import("dpmi/interrupts.zig").RealModeRegisters;
pub const simulateInterrupt = @import("dpmi/interrupts.zig").simulateInterrupt;
pub const simulateInterruptWithStack = @import("dpmi/interrupts.zig").simulateInterruptWithStack;
pub const getPageSize = @import("dpmi/paging.zig").getPageSize;
pub const DosMemoryBlock = @import("dpmi/DosMemoryBlock.zig");
pub const MemoryBlock = @import("dpmi/MemoryBlock.zig");
pub const Segment = @import("dpmi/Segment.zig");
