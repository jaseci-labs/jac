def _py_ctype_flags(c: int) -> int {
    if ((c >= 32) and (c <= 126)) {
        return 1;
    }

    return 0;
}

def pyctype_isprint(c: int) -> int {
    return ((_py_ctype_flags(c) & 1) != 0);
}
