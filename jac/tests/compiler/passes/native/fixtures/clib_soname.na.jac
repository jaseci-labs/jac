"""Minimal clib-import fixture for the DT_NEEDED soname regression test: the
logical lib `z` resolves to the system libz, and `compressBound` is a pure libz
function. The point is the link record, not the value."""
import from z { def compressBound(slen: u64) -> u64; }

with entry {
    print(int(compressBound(100)));
}
