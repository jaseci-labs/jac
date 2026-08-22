def _py_tolower(c: int) -> int {
    if ((c >= 65) and (c <= 90)) {
        return ((c + (97 - 65)) & 255);
    }

    return c;
}

def PyOS_mystricmp(s1: str, s2: str) -> int {
    p1: str = s1;
    p2: str = s2;
    while (
        ((ord(p1[0]) if p1 else 0) and (ord(p2[0]) if p2 else 0))
        and (
            _py_tolower((ord(p1[0]) if p1 else 0))
            == _py_tolower((ord(p2[0]) if p2 else 0))
        )
    ) {
        ;
        p1 = p1[1:];
        p2 = p2[1:];
    }

    return (
        _py_tolower((ord(p1[0]) if p1 else 0)) - _py_tolower((ord(p2[0]) if p2 else 0))
    );
}
