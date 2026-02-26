"""Tests for member access on union types.

When accessing a member on a union type (A | B), the member must exist
on ALL types in the union. The result type is the union of member types.
"""

obj Animal {
    has name: str = "animal";
}

obj Mammal(Animal) {
    has legs: int = 4;
}

obj Bird(Animal) {
    has wings: int = 2;
}

# 1. Member access on union - common member from base class
def test_union_common_member(x: Mammal | Bird) -> str {
    return x.name;  # <-- Ok, both have 'name' from Animal

}

# 2. Member access on union - member only on one type
# TODO: Should error when attribute error reporting is enabled
def test_union_uncommon_member(x: Mammal | Bird) -> int {
    return x.legs;  # Bird doesn't have 'legs' (error disabled for now)

}

# 3. Chained member access on union
obj Container {
    has animal: Mammal | Bird;
}

def test_union_chained_member(c: Container) -> str {
    return c.animal.name;  # <-- Ok, both have 'name'

}

# 4. Union with None - common member after narrowing
def test_union_with_none(x: Mammal | Bird | None) -> str {
    if x is not None {
        return x.name;  # <-- Ok, narrowed to Mammal | Bird

    }
    return "";
}
