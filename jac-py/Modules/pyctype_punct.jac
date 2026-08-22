def _py_ctype_flags(c: int) -> int {
    if (
        (
            (((c >= 33) and (c <= 47)) or ((c >= 58) and (c <= 64)))
            or ((c >= 91) and (c <= 96))
        )
        or ((c >= 123) and (c <= 126))
    ) {
        return 1;
    }

    return 0;
}

def pyctype_ispunct(c: int) -> int {
    return ((_py_ctype_flags(c) & 1) != 0);
}
