# P3.2e — unicode kind / length helpers (tiny slice; full unicode deferred).
# Lift: Objects/_lifted/unicodeobject_core.jac

glob PyUnicode_1BYTE_KIND: int = 1,
     PyUnicode_2BYTE_KIND: int = 2,
     PyUnicode_4BYTE_KIND: int = 4;

def unicode_kind_is_ascii(kind: int, maxchar: int) -> bool {
    return kind == PyUnicode_1BYTE_KIND and maxchar < 128;
}

def unicode_kind_width(kind: int) -> int {
    return kind;
}

def unicode_nbytes(length: int, kind: int) -> int {
    return length * kind;
}

def unicode_is_empty(length: int) -> bool {
    return length == 0;
}
