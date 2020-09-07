# DOS SDK for Zig

Write and cross-compile [DOS](https://wikipedia.org/wiki/DOS) programs with the
[Zig programming language](https://ziglang.org). Programs run in 32-bit
[protected mode](https://wikipedia.org/wiki/Protected_mode) and require a
resident [DPMI host](https://wikipedia.org/wiki/DOS_Protected_Mode_Interface).
[CWSDPMI](https://sandmann.dotster.com/cwsdpmi) is recommended for
environments that do not have DPMI built-in.

This package is still in a very primordial state. It is a minimal demonstration
of how to create a simple DOS program with Zig. Only basic file and terminal
input/output are working and proper error handling is non-existant. It will
require hacking if you wish to adapt it for your own needs.

## Quick Start

Install:

- [Zig](https://ziglang.org/download) (master)
- [DOSBox-X](https://dosbox-x.com)

Run:

```
zig build
dosbox-x -c 'cwsdpmi.exe -p' -c 'mount c zig-cache/bin' -c 'c:' -c 'execelf.exe'
```

## Design

There are four main components of this package:

- [DOS API](https://stanislavs.org/helppc/int_21.html) wrappers call the 16-bit
  real mode interrupt 21 routines (via DPMI). A transfer buffer residing in DOS
  memory is used if the program data resides in extended memory.
- [DPMI API](http://www.delorie.com/djgpp/doc/dpmi) wrappers are used to enter
  protected mode and manage memory.
- An [ELF](https://wikipedia.org/wiki/Executable_and_Linkable_Format) loader
  program is a [MZ executable](https://wikipedia.org/wiki/DOS_MZ_executable)
  (accomplished with a linker script) that can load and run an ELF file. It is
  currently a standalone program, but eventually it will act as a stub that can
  be prepended to an ELF file.
- The demo program is an ELF that exercises all of the above.

## Roadmap

- Proper error handling.
- Parse environment data (command, variables) and hook into standard library abstractions.
- Try to find and start a DPMI host (e.g. CWSDPMI) if DPMI is not detected.
- Implement `mprotect` for stack guard and zero pages.
- Implement a `page_allocator` for the standard library.
- Turn the ELF loader into prependable program stub.
- Add graphical demo program.

## Questions and Answers

### Why do I get an "Invalid Opcode" error in [DOSBox](https://www.dosbox.com)?

I have not looked into this deeply, but I believe it's because DOSBox does not
support the `cmov` instruction. LLVM fails to generate code if it is not
allowed to use `cmov`. I saw a commit for LLVM 11 that may resolve this issue,
so hopefully things work well with DOSBox once LLVM 11 is finalized and Zig
starts using it.

In the meantime, try using [DOSBox-X](https://dosbox-x.com).

### Can I just target 16-bit real mode rather than require DPMI?

It is possible, but it is a non-goal for this package. Zig (via LLVM) can
generate "16-bit" code using the `code16` ABI target. In reality, this code is
often 32-bit instructions with a bunch of added prefixes that allow them to
work when the processor is in a 16-bit compatibility mode. Using `code16`
actually produces *larger* binaries. Additionally, the oldest CPU that can be
targeted is an Intel 80386, which supports 32-bit protected mode. It's
guaranteed to be there and has a lot of advantages, so might as well use it.

### Why not piggyback off an existing DOS toolchain like DJGPP?

This was attempted and had mixed results. DJGPP's COFF and EXE formats are
subtly different from the ones produced by modern toolchains. Intermediate
conversion scripts had to be used to get them to work with DJGPP's linker and
stub tools, and it was not fool-proof. Ultimately, it felt like more trouble
than it was worth. Not relying on a separate toolchain will make things easier
in the long run.

### Why ELF instead of PE/COFF (i.e. the Windows executable format)?

Neither ELF nor PE/COFF are understood by DOS or any existing DOS extenders.
With that in mind, ELF was selected because it seems simpler, is the more
ubiquitous format overall, and Zig's standard library has a good ELF parser!
