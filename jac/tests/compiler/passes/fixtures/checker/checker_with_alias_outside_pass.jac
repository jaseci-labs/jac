"""Fixture: a native `with open(...) as` alias read before any checker pass.

Typed with no pass running (as an import's interface build does), `open` must
still resolve to the native builtin (a binary mode gives `BinaryFile`) and the
alias must bind through `__enter__`.
"""

def load(path: str) -> bytes {
    with open(path, "rb") as stream {
        return stream.read();
    }
}
