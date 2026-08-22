def _py_ctype_flags(c: int) -> int {
    if ((c >= 48) and (c <= 57)) {
        return 4;
    }

    return 0;
}

def pyctype_isdigit(c: int) -> int {
    return ((_py_ctype_flags(c) & 4) != 0);
}
