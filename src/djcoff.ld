/* Linker script to produce a DJGPP COFF executable. */
/* See: http://www.delorie.com/djgpp/doc/coff/ */

PROVIDE(_stack_size = 0x8000); /* TODO: Get stack size from toolchain? */

SECTIONS {
    . = 0;
    /* COFF file header */
    .file_head : {
        SHORT(0x14c) /* Magic number */
        SHORT(3)     /* Section count */
        LONG(0)      /* Timestamp */
        LONG(0)      /* Symbol table file offset */
        LONG(0)      /* Symbol count */
        SHORT(SIZEOF(.opt_head))
        SHORT(0x10f) /* Flags */
    }
    /* Optional (executable) header */
    .opt_head : {
        SHORT(0x10b)           /* Magic number */
        SHORT(0)               /* Version */
        LONG(SIZEOF(.text))    /* Text section size */
        LONG(SIZEOF(.data))    /* Data section size */
        LONG(SIZEOF(.bss))     /* BSS section size */
        LONG(ABSOLUTE(_start)) /* Entry point */
        LONG(ADDR(.text))      /* Text file offset */
        LONG(ADDR(.data))      /* Data file offset */
    }
    /* Text section header */
    .text_head : {
        /* Section name */
        BYTE(0x2e) /* . */
        BYTE(0x74) /* t */
        BYTE(0x65) /* e */
        BYTE(0x78) /* x */
        BYTE(0x74) /* t */
        BYTE(0)
        BYTE(0)
        BYTE(0)

        LONG(ADDR(.text))   /* Physical address */
        LONG(ADDR(.text))   /* Virtual address */
        LONG(SIZEOF(.text)) /* Section size */
        LONG(ADDR(.text))   /* File offset to section */
        LONG(0)             /* File offset to relocations */
        LONG(0)             /* File offset to line numbers */
        SHORT(0)            /* Relocation count */
        SHORT(0)            /* Line number count */
        LONG(0x20)          /* Flags */
    }
    /* Data section header */
    .data_head : {
        /* Section name */
        BYTE(0x2e) /* . */
        BYTE(0x64) /* d */
        BYTE(0x61) /* a */
        BYTE(0x74) /* t */
        BYTE(0x61) /* a */
        BYTE(0)
        BYTE(0)
        BYTE(0)

        LONG(ADDR(.data))   /* Physical address */
        LONG(ADDR(.data))   /* Virtual address */
        LONG(SIZEOF(.data)) /* Section size */
        LONG(ADDR(.data))   /* File offset to section */
        LONG(0)             /* File offset to relocations */
        LONG(0)             /* File offset to line numbers */
        SHORT(0)            /* Relocation count */
        SHORT(0)            /* Line number count */
        LONG(0x40)          /* Flags */
    }
    /* BSS section header */
    .bss_head : {
        /* Section name */
        BYTE(0x2e) /* . */
        BYTE(0x62) /* b */
        BYTE(0x73) /* s */
        BYTE(0x73) /* s */
        BYTE(0)
        BYTE(0)
        BYTE(0)
        BYTE(0)

        LONG(ADDR(.bss))    /* Physical address */
        LONG(ADDR(.bss))    /* Virtual address */
        LONG(SIZEOF(.bss))  /* Section size */
        LONG(0)             /* File offset to section */
        LONG(0)             /* File offset to relocations */
        LONG(0)             /* File offset to line numbers */
        SHORT(0)            /* Relocation count */
        SHORT(0)            /* Line number count */
        LONG(0x80)          /* Flags */
    }
    .text : {
        *(.text*)
    }
    .data : {
        *(.rodata*)
        *(.data*)
    }
    .bss : {
        *(.bss*)
        . += _stack_size;
        . = ALIGN(16);
        _stack_ptr = ABSOLUTE(.);
    }
}
