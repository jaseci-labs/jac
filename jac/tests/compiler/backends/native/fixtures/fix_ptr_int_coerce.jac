"""Fixture for pointer and integer coercion at the C boundary.

C memory stays on the explicit C surface: `ptr[u8]` for C strings and
buffers. `strlen` here takes the address as an `int`, so a `ptr[u8]`
argument converts to its integer address (ptrtoint); `calloc` returns its
buffer as an `int`, and `ptr[u8](...)` turns the address back into a
pointer (inttoptr) before it is measured and freed.
"""

import from "/usr/lib/x86_64-linux-gnu/libc.so.6" {
    def strlen(s: int) -> int;  def calloc(n: int, sz: int) -> int;  def free(
        p: ptr[u8]
    );
}

def:pub test_ptrtoint_strlen -> int {
    return strlen(int(ptr[u8]("hello")));
}

def:pub test_ptrtoint_strlen_empty -> int {
    return strlen(int(ptr[u8]("")));
}

def:pub test_inttoptr_calloc -> int {
    buf = ptr[u8](calloc(16, 1));
    result = strlen(int(buf));
    free(buf);
    return result;
}
