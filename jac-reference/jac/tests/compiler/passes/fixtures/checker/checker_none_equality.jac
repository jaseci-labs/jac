"""Equality against None must type-check (#7922).

Python equality never fails to resolve -- object.__eq__/__ne__ are the
universal identity fallback -- so none of these may raise E1110. The
checker previously rejected them because typeshed's NoneType declares no
__eq__, steering users toward `is None` (which was the broken spelling
on two backends).
"""

def probe(x: (int | None)) -> int {
    a: int = 1 if (None == None) else 0;
    b: int = 1 if (x == None) else 0;
    c: int = 1 if (x != None) else 0;
    d: int = 1 if (None != None) else 0;
    return a + b + c + d;
}

with entry {
    print(probe(None));
}
