def _py_ctype_flags(c: int) -> int {
    if ((c >= 97) and (c <= 122)) {
        return 1;
    }

    return 0;
}

def pyctype_islower(c: int) -> int {
    return ((_py_ctype_flags(c) & 1) != 0);
}
