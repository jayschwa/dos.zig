block = 512;
paragraph = 16;

psp_size = 256; /* Size of the Program Segment Prefix. */
exe_file_size = SIZEOF(.mz_head) + SIZEOF(.exe_data);
PROVIDE(_stack_size = 0x8000); /* TODO: Get stack size from toolchain? */

SECTIONS {
    /* Executable data is loaded in after the Program Segment Prefix. */
    . = psp_size - SIZEOF(.mz_head);

    .mz_head : ALIGN(paragraph) {
        /* "MZ" signature. */
        SHORT(0x5A4D)

        /* Number of bytes in last block. */
        SHORT(exe_file_size % block)

        /* Number of blocks in the executable. */
        SHORT(ALIGN(exe_file_size, block) / block)

        /* Number of relocation entries. */
        SHORT(0)

        /* Number of paragraphs in this header. */
        SHORT(SIZEOF(.mz_head) / paragraph)

        /* Number of paragraphs of extra memory needed during runtime. */
        SHORT(SIZEOF(.alloc) / paragraph) /* Minimum */
        SHORT(SIZEOF(.alloc) / paragraph) /* Maximum */

        /* Initial relative stack segment. */
        SHORT(-psp_size / paragraph)

        /* Initial stack pointer. */
        SHORT(stack_ptr)

        /* Checksum. */
        SHORT(0)

        /* Initial instruction pointer. */
        SHORT(ABSOLUTE(_start))

        /* Initial relative code segment. */
        SHORT(-psp_size / paragraph)

        /* File offset to relocation table. */
        SHORT(0)

        /* Overlay number. */
        SHORT(0)
    }

    .exe_data : {
        *(.text*)
        *(.rodata*)
        *(.data*)
    }

    .alloc (NOLOAD) : ALIGN(paragraph) {
        _bss_start = ABSOLUTE(.);
        *(.bss*)
        _bss_end = ABSOLUTE(.);
        . += _stack_size;
        . = ALIGN(paragraph);
    }

    stack_ptr = ABSOLUTE(.);

    ASSERT(stack_ptr < 64K, "Error: Program exceeds a single 64 KiB segment.")
}
