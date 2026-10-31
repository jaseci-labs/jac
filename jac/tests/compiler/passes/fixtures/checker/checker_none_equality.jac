"""Equality against None must type-check (#7922).

Python equality never fails to resolve -- object.__eq__/__ne__ are the
universal identity fallback -- so none of these may raise E1110. The
checker previously rejected them because typeshed's NoneType declares no
__eq__, steering users toward `is None` (which was the broken spelling
on two backends).

Ordering numeric unions such as `int | float` is valid for every pairing of
members, so it may not raise E1110 either.
"""

def ordered(x: (int | float), y: (int | float)) -> bool {
    return x < y and x <= 1 and 2.0 > y;
}

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
