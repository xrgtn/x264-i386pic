# x264-i386pic

## Intro

As of mid-2024, on 32-bit x86 Gentoo GNU/Linux libx264 is built by default with
PIC (Position-Independent Code) enabled and optimized assembler code disabled:
`--enable-pic --disable-asm` (former implies latter). Encoding is several times
slower with such libx264, but it looks like nobody cares nowadays about x264
speed on *obsolete* i386 platform.

## Goal

This project aims to convert i386 asm sources to PIC without breaking anything,
with the least possible slowdown resulting from such a conversion, and possibly
optimizing asm code even more.

## Status

Current state of affairs is such:
* all asm sources that generated `read-only segment has dynamic relocations`
  errors (and `relocation in read-only section '.text'` warnings) have been
  **fixed** (converted to PIC)
* x264 **builds** with PIC+asm just fine
* it looks like this new x264 **works** OK: it didn't crash, encoding was 3.3
  times faster than no-asm version (on Control/2007), encoded video looks the
  same
* Currently I don't have an idea how to unit-test all asm functions vs C
  versions, or where to get reference input and output, plus this sounds like
  several times more work than converting those 800 kilobytes of asm to PIC...
* I unrolled loops in several asm functions
* at least one function used to calculate stack alignment wrong way, I fixed it

## vs upstream

I didn't contact upstream, it requires (apparently) reporting via maillist or
whatever, but I'm too lazy and don't like maillists, sorry. And nobody needs
optimizations for *i386* in this Brave New Age anyway.
