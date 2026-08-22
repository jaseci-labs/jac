def _py_ctype_flags(c: int) -> int {
    if (
        (((((c == 32) or (c == 9)) or (c == 10)) or (c == 11)) or (c == 12))
        or (c == 13)
    ) {
        return 1;
    }

    return 0;
}

def pyctype_isspace(c: int) -> int {
    return ((_py_ctype_flags(c) & 1) != 0);
}
