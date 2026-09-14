pub const DosMemoryBlock = @import("dpmi/DosMemoryBlock.zig");
const interrupts = @import("dpmi/interrupts.zig");
pub const RealModeRegisters = interrupts.RealModeRegisters;
pub const simulateInterrupt = interrupts.simulateInterrupt;
pub const simulateInterruptWithStack = interrupts.simulateInterruptWithStack;
pub const MemoryBlock = @import("dpmi/MemoryBlock.zig");
pub const getPageSize = @import("dpmi/paging.zig").getPageSize;
pub const Segment = @import("dpmi/Segment.zig");
