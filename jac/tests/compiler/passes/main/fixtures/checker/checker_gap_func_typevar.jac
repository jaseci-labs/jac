"""Gap: Function-level TypeVar resolution.

Generic functions like find_parent_of_type[T](typ: type[T]) -> T | None
should resolve T from the argument at the call site and return the
specialized type. Without this, the return type stays Unknown and
every attribute access on the result is a false error.

Expected errors:
  1. wrong_type: int assigned to str (proves T=int was solved)
  2. wrong_type2: str assigned to int (proves T=str was solved)
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

with entry {
    # identity[T](val: T) -> T
    ok1: int = identity(42);
    ok2: str = identity("hello");
    wrong_type: str = identity(42);     # Error: int not assignable to str
    wrong_type2: int = identity("hi");  # Error: str not assignable to int

    # make_or_none[T](typ: type[T]) -> T | None
    result1: Animal | None = make_or_none(Animal);   # Ok
    result2: Dog | None = make_or_none(Dog);         # Ok

    # first_of_type[T](items: list, typ: type[T]) -> T | None
    animals: list = [Dog(), Cat()];
    found: Dog | None = first_of_type(animals, Dog);     # Ok
    found2: Cat | None = first_of_type(animals, Cat);    # Ok
}
