"""Reflection inside a function body: demotable to a native seam.

`probe` owns the violation, so the capability partition hands it to the seam
census and leaves `pure` native, exactly as a body-scoped Python import does.
"""

obj Foo {
    has x: int = 1;
}


def probe(f: Foo) -> bool {
    return hasattr(f, "x");
}


def pure(n: int) -> int {
    return n * 2;
}
