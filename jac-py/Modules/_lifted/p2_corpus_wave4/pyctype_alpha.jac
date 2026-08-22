def _py_ctype_flags(c: int) -> int {
    if ((c >= 65) and (c <= 90)) {
        return 2;
    }

    if ((c >= 97) and (c <= 122)) {
        return 4;
    }

    return 0;
}

def pyctype_isalpha(c: int) -> int {
    flags: int = _py_ctype_flags(c);
    return ((flags & (2 | 4)) != 0);
}
