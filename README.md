# DOS SDK for Zig

Write and cross-compile [DOS](https://wikipedia.org/wiki/DOS) programs with the
[Zig programming language](https://ziglang.org). Programs run in 32-bit
[protected mode](https://wikipedia.org/wiki/Protected_mode) and require a
resident [DPMI host](https://wikipedia.org/wiki/DOS_Protected_Mode_Interface).
[CWSDPMI](https://sandmann.dotster.com/cwsdpmi) is bundled with the executable
for environments that do not have DPMI available.

To comply with the [CWSDPMI license](https://sandmann.dotster.com/cwsdpmi/cwsdpmi.txt),
published programs must provide notice to users that they have the right to
receive the source code and/or binary updates for CWSDPMI. Distributors should
indicate a site for the source in their documentation.

This package is in a primordial state. It is a minimal demonstration of how to
create a simple DOS program with Zig. Only basic file/terminal input/output are
working, and does not include proper error handling. It will require hacking if
you wish to adapt it for your own needs.

## Quick Start

Install:

- [Zig](https://ziglang.org/download) (master)
- [DOSBox](https://www.dosbox.com)

Run:

``` sh
zig build run
```

## Design

There are five main components of this package:

- [DOS API](https://stanislavs.org/helppc/int_21.html) wrappers call the 16-bit
  real mode interrupt 21 routines (via DPMI) and implement operating system
  interfaces for the Zig standard library.
- [DPMI API](http://www.delorie.com/djgpp/doc/dpmi) wrappers manage extended
  memory blocks and segments.
- A custom [linker script](https://sourceware.org/binutils/docs/ld/Scripts.html)
  produces [DJGPP COFF](http://www.delorie.com/djgpp/doc/coff) executables.
- The [CWSDPMI](https://sandmann.dotster.com/cwsdpmi) stub loader enters
  protected mode and runs the COFF executable attached to it.
- A small demo program exercises all of the above.

## Roadmap

- Proper error handling.
- Parse environment data (command, variables) and hook into standard library abstractions.
- Implement `mprotect` for stack guard and zero pages.
- Implement a `page_allocator` for the standard library.
- Add graphical demo program.

## Questions and Answers

### Can I just target 16-bit real mode rather than require DPMI?

It is technically possible, but not a goal of this package. Zig (via LLVM) can
generate "16-bit" code using the `code16` ABI target. In reality, this code is
often 32-bit instructions with added prefixes that override the address or
operand size. Using `code16` actually produces *larger* binaries. Additionally,
the oldest CPU that can be targeted is an Intel 80386, which supports 32-bit
protected mode. It's guaranteed to be there and has a lot of advantages, so we
might as well use it.

### Why not integrate with an existing DOS toolchain like DJGPP?

This was attempted and had mixed results. DJGPP's object format (COFF) is
subtly different from the one produced by modern toolchains such as Zig. Crude
conversion scripts had to be used to get them to work together and it was not
robust. While it would be nice to leverage DJGPP's C library, it ultimately
felt like more trouble than it was worth. Not relying on a separate toolchain
will make things easier in the long run.
