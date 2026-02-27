"""Tests for member access on union types."""

obj Animal {
    has name: str = "animal";
}

obj Mammal(Animal) {
    has legs: int = 4;
}

obj Bird(Animal) {
    has wings: int = 2;
}

def test_union_common_member(x: Mammal | Bird) -> str {
    return x.name;  # Ok

}

# TODO: Should error when attribute error reporting is enabled
def test_union_uncommon_member(x: Mammal | Bird) -> int {
    return x.legs;  # Error (disabled for now)

}

obj Container {
    has animal: Mammal | Bird;
}

def test_union_chained_member(c: Container) -> str {
    return c.animal.name;  # Ok

}

def test_union_with_none(x: Mammal | Bird | None) -> str {
    if x is not None {
        return x.name;  # Ok

    }
    return "";
}
