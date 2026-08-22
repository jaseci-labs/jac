def py_tolower(c: int) -> int {
    return (c + 32) if ((c >= 65) and (c <= 90)) else c;
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
            py_tolower((ord(p1[0]) if p1 else 0))
            == py_tolower((ord(p2[0]) if p2 else 0))
        )
    ) {
        ;
        p1 = p1[1:];
        p2 = p2[1:];
    }

    return (
        py_tolower((ord(p1[0]) if p1 else 0)) - py_tolower((ord(p2[0]) if p2 else 0))
    );
}

def PyOS_mystricmp(s1: str, s2: str) -> int {
    p1: str = s1;
    p2: str = s2;
    while (
        ((ord(p1[0]) if p1 else 0) and (ord(p2[0]) if p2 else 0))
        and (
            py_tolower((ord(p1[0]) if p1 else 0))
            == py_tolower((ord(p2[0]) if p2 else 0))
        )
    ) {
        ;
        p1 = p1[1:];
        p2 = p2[1:];
    }

    return (
        py_tolower((ord(p1[0]) if p1 else 0)) - py_tolower((ord(p2[0]) if p2 else 0))
    );
}
