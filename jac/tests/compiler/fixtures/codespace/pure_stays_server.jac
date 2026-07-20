"""Native compatibility alone never infers native placement.

Pure computation is native-COMPATIBLE, but compatibility never implies
placement: unmarked code with no FFI surface defaults to server. Native
inference needs an extern-decl import seed; otherwise going native stays
an explicit build choice (`na {}`, `.na.jac`, or nacompile auto-promotion
of a target module).
"""

def add(a: int, b: int) -> int {
    return a + b;
}

def mul_add(a: int, b: int, c: int) -> int {
    return add(a * b, c);
}
