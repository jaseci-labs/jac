"""Gap: Function-level TypeVar resolution.

Generic functions should resolve T from the argument at the call site
and return the specialized type. Without this, return types stay Unknown
and attribute accesses on results produce false errors.
"""

obj Animal {
    has name: str = "animal";
}

obj Dog(Animal) {
    has breed: str = "unknown";
}

obj Cat(Animal) {
    has indoor: bool = True;
}

def identity[T](val: T) -> T {
    return val;
}

def make_or_none[T](typ: type[T]) -> T | None {
    return None;
}

def first_of_type[T](items: list, typ: type[T]) -> T | None {
    for item in items {
        if isinstance(item, typ) {
            return item;
        }
    }
    return None;
}

def swap[T, U](a: T, b: U) -> tuple[U, T] {
    return (b, a);
}

with entry {
    # identity[T] — positional and keyword
    ok1: int = identity(42);
    ok2: str = identity("hello");
    ok_kw: int = identity(val=42);

    # make_or_none[T]
    result1: Animal | None = make_or_none(Animal);
    result2: Dog | None = make_or_none(Dog);

    # first_of_type[T]
    animals: list = [Dog(), Cat()];
    found: Dog | None = first_of_type(animals, Dog);
    found2: Cat | None = first_of_type(animals, Cat);

    # swap[T, U] — 2 TypeVars
    ok_swap: tuple[str, int] = swap(42, "hi");
}
