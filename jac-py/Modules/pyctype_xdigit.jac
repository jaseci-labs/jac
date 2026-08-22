def _py_ctype_flags(c: int) -> int {
    if ((c >= 48) and (c <= 57)) {
        return (4 | 16);
    }

    if (((c >= 65) and (c <= 70)) or ((c >= 97) and (c <= 102))) {
        return 16;
    }

    return 0;
}

def pyctype_isxdigit(c: int) -> int {
    return ((_py_ctype_flags(c) & 16) != 0);
}
