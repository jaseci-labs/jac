def _py_ctype_flags(c: int) -> int {
    if ((c >= 48) and (c <= 57)) {
        return 8;
    }

    if ((c >= 65) and (c <= 90)) {
        return 2;
    }

    if ((c >= 97) and (c <= 122)) {
        return 4;
    }

    return 0;
}

def pyctype_isalnum(c: int) -> int {
    return ((_py_ctype_flags(c) & ((2 | 4) | 8)) != 0);
}
