"""Fixture: module-level singletons declared without a type annotation."""

obj Code {
    has name: str;
}

def _code(name: str) -> Code {
    return Code(name=name);
}

glob FIRST = _code("first"),
     SECOND = _code("second");
