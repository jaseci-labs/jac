"""Gap #51: Generic functions should resolve TypeVars at call sites."""

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
    ok1 = identity(42);
    ok2 = identity("hello");
    ok_kw = identity(val=42);

    # make_or_none[T]
    result1 = make_or_none(Animal);
    result2 = make_or_none(Dog);

    # first_of_type[T]
    animals = [Dog(), Cat()];
    found = first_of_type(animals, Dog);
    found2 = first_of_type(animals, Cat);

    # swap[T, U] — 2 TypeVars
    ok_swap = swap(42, "hi");
}
