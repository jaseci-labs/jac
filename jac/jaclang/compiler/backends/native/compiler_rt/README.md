# AArch64 compiler runtime

Unmodified LLVM compiler-rt builtins from `llvmorg-22.1.8`, matching the LLVM pin
in `bootstrap/pins.json`. Upstream: https://github.com/llvm/llvm-project/tree/llvmorg-22.1.8/compiler-rt/lib/builtins

The payload vendor builds each outline-atomic entry point as its own archive
member, plus upstream CPU detection with `DISABLE_AARCH64_FMV`. This allows the
existing archive linker to select required helpers without importing unrelated
libc definitions. The helpers preserve the compiler ABI and use runtime LSE
detection with the upstream LL/SC fallback. This source subset supports Linux.

`SOURCES.sha256` records upstream file hashes. Retain the LLVM license when
updating the sources.
