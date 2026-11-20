obj Left {
    has value: int = 3;
    has items: list[int] { getter; }
}

impl Left.items.getter -> list[int] {
    return [self.value, self.value + 1];
}

obj Right {
    has padding: str = "different layout",
        value: int = 10;

    has items: list[int] { getter; }
}

impl Right.items.getter -> list[int] {
    return [self.value];
}

obj Stored {
    has items: list[int] = [5, 6];
}

def total(value: Left | Right | Stored) -> int {
    result = 0;
    for item in value.items {
        result += item;
    }
    return result;
}

def probe(which: int) -> int {
    if which == 0 {
        return total(Left());
    }
    if which == 2 {
        value = Stored();
        first = total(value);
        return first + total(value);
    }
    return total(Right());
}

with entry {
    assert probe(0) == 7;
    assert probe(1) == 10;
    assert probe(2) == 22;
}
