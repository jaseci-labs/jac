def _py_ctype_flags(c: int) -> int {
    if ((c <= 31) or (c == 127)) {
        return 1;
    }

    return 0;
}

def pyctype_iscntrl(c: int) -> int {
    return ((_py_ctype_flags(c) & 1) != 0);
}
