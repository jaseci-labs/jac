"""Generic archetype with an optional erased slot, owned by another module.

The consumer builds `Ctx[Leaf]` itself and also takes cells this module built,
so the constructor store is covered on both sides of the import: the slot the
importer filled and the slot this module filled.
"""

obj Leaf {
    has num: int = 0,
        name: str = "";
}

obj Ctx[T] {
    has value: (T | None) = None,
        tag: int = 0;
}

def build(n: int) -> Ctx[Leaf] {
    return Ctx[Leaf](value=Leaf(num=n, name="lib"), tag=n * 2);
}
