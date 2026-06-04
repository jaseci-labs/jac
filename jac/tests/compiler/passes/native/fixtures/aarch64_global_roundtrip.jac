"""aarch64 ELF linker round-trip fixture (regression for issue #6366).

`total` is a module-level global, so storing and reloading it emits a
movz/movk absolute-address chain relocated by R_AARCH64_MOVW_UABS_G0..G3.
If the in-house linker drops those relocations the address stays NULL and
the binary segfaults at entry. The exit code carries the computed value so
the test confirms the global actually round-trips, not merely that the
process avoided a crash.
"""
import sys;

def add(a: int, b: int) -> int { return a + b; }

with entry {
    total = add(40, 2);
    sys.exit(total);
}
