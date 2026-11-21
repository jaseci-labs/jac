"""Fixture for duplicate-clib-symbol fix test.

Explicitly imports 'strlen' from libc.  The compiler also uses strlen
internally for string operations.  Before the fix, both declarations
landed in the same LLVM module and llvmlite raised DuplicatedNameError.
After the fix, _get_or_declare_extern re-uses the existing declaration.

We also import 'memcpy', 'calloc', and 'free' — all pre-declared by
_emit_rc_helpers — to exercise the full dedup path.
"""

import from "/usr/lib/x86_64-linux-gnu/libc.so.6" {
    def strlen(s: str) -> int;
    def memcpy(dst: str, src: str, n: int) -> str;
    def calloc(nmemb: int, size: int) -> str;
    def free(ptr: str);
}

def:pub test_strlen_hello() -> int {
    # strlen("hello") == 5 via the user-declared extern
    return strlen("hello");
}

def:pub test_strlen_empty() -> int {
    return strlen("");
}

with entry {}
