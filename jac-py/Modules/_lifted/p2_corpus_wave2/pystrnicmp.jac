def _py_tolower(c: int) -> int {
    if ((c >= 65) and (c <= 90)) {
        return ((c + (97 - 65)) & 255);
    }

    return c;
}

def PyOS_mystrnicmp(s1: str, s2: str, size: int) -> int {
    p1: str = str();
    p2: str = str();
    if (size == 0) {
        return 0;
    }

    p1 = s1;
    p2 = s2;
    while (
        (
            (((size := size - 1) > 0) and (ord(p1[0]) if p1 else 0))
            and (ord(p2[0]) if p2 else 0)
        )
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
