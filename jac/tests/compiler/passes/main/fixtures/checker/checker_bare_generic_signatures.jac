"""Bare generics in function signatures (return types and parameters) and
union branches should produce W1036 warnings, just like bare-generic field
and assignment annotations do."""

# Bare return type
def returns_bare_list -> list {
    return [];
}

# Bare param type
def takes_bare_dict(x: dict) -> None {
    print(x);
}

# Bare generic inside a union branch
def returns_optional_bare -> list | None {
    return None;
}

# Multiple bare generics: param + return
def both_bare(x: list, y: dict) -> set {
    return set();
}

# Properly parameterized: should NOT warn
def returns_typed_list -> list[int] {
    return [1, 2, 3];
}

def takes_typed_dict(x: dict[str, int]) -> None {
    print(x);
}

# Method on an object
obj Container {
    def get_items -> tuple;
    def set_items(items: frozenset) -> None;
}

impl Container.get_items -> tuple {
    return ();
}

impl Container.set_items(items: frozenset) -> None {
    print(items);
}
