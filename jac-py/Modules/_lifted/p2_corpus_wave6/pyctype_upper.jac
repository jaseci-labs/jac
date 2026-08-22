def _py_ctype_flags(c: int) -> int {
    if ((c >= 65) and (c <= 90)) {
        return 1;
    }

    return 0;
}

def pyctype_isupper(c: int) -> int {
    return ((_py_ctype_flags(c) & 1) != 0);
}
