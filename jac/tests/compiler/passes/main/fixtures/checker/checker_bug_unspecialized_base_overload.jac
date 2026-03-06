"""Bug #21: _get_method_with_overloads doesn't specialize the base method.

In _get_method_with_overloads, the base method (method_ty) is added to
overloaded_fns without calling specialize(), but overload variants ARE
specialized. This means the first overload has unresolved TypeVars while
others have concrete types, causing inconsistent overload resolution.

This test exposes the issue with a generic class that has overloaded methods.
"""

obj Container[T] {
    has items: list[T] = [];

    def get(index: int) -> T {
        return self.items[index];
    }

    def get(key: str) -> T {
        return self.items[0];
    }
}

with entry {
    c = Container[int](items=[1, 2, 3]);

    # Both overloads should resolve T -> int after specialization
    r1: int = c.get(0);  # <-- Should be Ok (int -> int)
    r2: int = c.get("key");  # <-- Should be Ok (int -> int)

    # These should error because T is int, not str
    r3: str = c.get(0);  # <-- Should be Error (int not assignable to str)
    r4: str = c.get("key");  # <-- Should be Error
}
