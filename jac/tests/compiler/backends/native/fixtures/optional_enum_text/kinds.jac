import from enum { IntEnum, auto }

class Category(IntEnum) {
    with entry {
        First = auto();
        Second = auto();
    }
}

obj Param {
    has name: str,
        category: (Category | None) = None;
}

node Shape {
    has sides: int = 0;
}
