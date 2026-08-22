def _py_ctype_flags(c: int) -> int {
    if ((c == 32) or (c == 9)) {
        return 1;
    }

    return 0;
}

def pyctype_isblank(c: int) -> int {
    return ((_py_ctype_flags(c) & 1) != 0);
}
