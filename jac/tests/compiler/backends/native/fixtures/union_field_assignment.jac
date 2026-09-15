"""Union writes must use the concrete layout and retain optional objects."""
obj Base {}
obj Value {
    has number: int;
}
obj First(Base) {
    has value: Value | None,
        guard: int = 17;
}
obj Second(Base) {
    has padding: str = "padding",
        guard: int = 23,
        value: Value | None = None;
}

def replace(value: Base) {
    if isinstance(value, (First, Second)) and value.value is not None {
        value.value = Value(number=42);
    }
}

def probe(pick: int) -> int {
    value: Base = First(value=Value(number=1))
        if pick == 0
        else Second(value=Value(number=2));
    replace(value);
    if isinstance(value, First) and value.value is not None {
        return value.value.number + value.guard;
    } elif isinstance(value, Second) and value.value is not None {
        return value.value.number + value.guard + len(value.padding);
    }
    return -1;
}
