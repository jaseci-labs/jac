"""Minimal C-ABI shared-library fixture for the dylib load-command tests.

A scalar-only export surface (`:pub` free functions + a `:pub` global) — no
object handles, so it compiles through the native pathway without depending on
object attribute-access support. Enough to drive the shared-object linkers far
enough to assert on the emitted Mach-O load commands and code signature.
"""

glob:pub counter: int = 7;

def:pub jadd(a: int, b: int) -> int {
    return a + b;
}

def:pub jmul(a: int, b: int) -> int {
    return a * b;
}

def:pub get_counter() -> int {
    return counter;
}

with entry {}
