"""Fixture for pointer-to-integer coercion fix test.

Declares 'strlen' with an 'int' parameter instead of 'str'.  In LLVM IR
the Jac 'str' type is i8*, while 'int' is i64.  When calling strlen("hello"),
the compiler must emit a ptrtoint instruction to convert the i8* string
pointer to i64.  Before the fix _coerce_type had no generic PointerType→IntType
path and the call crashed with an IR type mismatch.

Also declares 'calloc' with return type 'int' and assigns the result to a
'str' local to test the IntType→PointerType (inttoptr) coercion direction.
"""

import from "/usr/lib/x86_64-linux-gnu/libc.so.6" {
    def strlen(s: int) -> int;      # int param forces ptrtoint(str → i64)
    def calloc(n: int, sz: int) -> int;  # int return forces inttoptr when stored as str
    def free(p: str);
}

def:pub test_ptrtoint_strlen() -> int {
    # "hello" is i8* but strlen param is i64 — compiler emits ptrtoint
    return strlen("hello");
}

def:pub test_ptrtoint_strlen_empty() -> int {
    return strlen("");
}

def:pub test_inttoptr_calloc() -> int {
    # calloc returns i64 (declared as int); we assign to str (i8*) — inttoptr
    buf: str = calloc(16, 1);
    # A non-null buffer can be used as a string (starts as all-zeros → empty)
    result: int = strlen(buf);
    free(buf);
    return result;  # calloc zeroes memory, so strlen == 0
}

with entry {}
