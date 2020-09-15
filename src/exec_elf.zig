const std = @import("std");
const elf = std.elf;
const math = std.math;
const mem = std.mem;

const dos = @import("dos");
const dpmi = dos.dpmi;

pub const os = dos;

pub fn main() !void {
    const loaded_elf = try loadElf("demo");

    // Switch to loaded ELF segments and jump to its entry point.
    asm volatile (
        \\ mov %[data], %%ds
        \\ mov %[data], %%es
        \\ mov %[data], %%ss
        \\ mov %[stack], %%ebp
        \\ mov %[stack], %%esp
        \\ push %[code]
        \\ push %[entry]
        \\ lretl
        : // No outputs
        : [code] "r" (loaded_elf.code_segment.selector),
          [data] "r" (loaded_elf.data_segment.selector),
          [entry] "r" (loaded_elf.entry_addr),
          [stack] "r" (loaded_elf.stack_addr)
    );
    unreachable;
}

const LoadedElf = struct {
    code_segment: dpmi.Segment,
    data_segment: dpmi.Segment,
    entry_addr: usize,
    stack_addr: usize,
};

pub fn loadElf(path: []const u8) !LoadedElf {
    const elf_file = try dos.openFile(path);
    defer elf_file.close();

    // Parse ELF header and enforce constraints.
    const elf_header = try elf.readHeader(elf_file);
    if (elf_header.is_64) return error.UnsupportedElf;
    if (elf_header.endian != std.builtin.endian) return error.UnsupportedElf;
    // TODO: Expose ELF type instead and check that it's EXEC.

    // Questions to answer about program.
    var base_addr: ?usize = null;
    var stack_size: usize = 0x100000; // 1 MiB default
    var mem_needed: usize = 0;

    // Iterate over program headers and determine amount of memory required.
    var phdr_iter = elf_header.program_header_iterator(elf_file);
    while (try phdr_iter.next()) |header| {
        // TODO: Handle GNU_STACK program headers.
        if (header.p_type != elf.PT_LOAD) continue;

        // Derive base address from first loadable segment.
        if (base_addr == null) base_addr = @truncate(usize, header.p_vaddr);

        // Update memory requirements.
        const offset_in_mem = @truncate(usize, header.p_vaddr);
        const size_in_mem = @truncate(usize, header.p_memsz);
        mem_needed = math.max(offset_in_mem + size_in_mem, mem_needed);
    }

    // Include stack size in memory requirements and round up to nearest page.
    // TODO: Make room for a stack guard page.
    mem_needed = mem.alignForward(mem_needed + stack_size, dpmi.getPageSize());

    // Allocate extended memory for program.
    const mem_block = try dpmi.ExtMemBlock.alloc(mem_needed);
    // TODO: errdefer free block.

    // TODO: Set tighter limit on code segment.
    const code_segment = mem_block.createSegment(.Code);
    // TODO: errdefer free descriptor.
    const data_segment = mem_block.createSegment(.Data);
    // TODO: errdefer free descriptor.

    // Iterate over program headers and setup loadable memory segments.
    phdr_iter = elf_header.program_header_iterator(elf_file);
    while (try phdr_iter.next()) |header| {
        if (header.p_type != elf.PT_LOAD) continue;

        // Memory segment attributes.
        const offset_in_elf = @truncate(usize, header.p_offset);
        const offset_in_mem = @truncate(usize, header.p_vaddr);
        const size_in_elf = @truncate(usize, header.p_filesz);
        const size_in_mem = @truncate(usize, header.p_memsz);

        // Copy data from ELF file into memory.
        var copied: usize = 0;
        while (copied < size_in_elf) {
            var buffer: [0x4000]u8 = undefined; // 16 KiB
            var read_size = math.min(buffer.len, size_in_elf - copied);
            read_size = try elf_file.pread(buffer[0..read_size], offset_in_elf + copied);
            data_segment.writeAt(buffer[0..read_size], offset_in_mem + copied);
            copied += read_size;
        }

        // Zero out any remaining space.
        if (size_in_mem > size_in_elf) {
            data_segment.zeroAt(offset_in_mem + size_in_elf, size_in_mem - size_in_elf);
        }
    }

    return LoadedElf{
        .code_segment = code_segment,
        .data_segment = data_segment,
        .entry_addr = @truncate(usize, elf_header.entry),
        .stack_addr = mem.alignBackward(mem_block.len - 1, 16),
    };
}
