"""TypeVar scoping in detached `impl` blocks.

A separate `impl Box.method` block is lexically a sibling of `obj Box[T]`, so
neither the archetype nor the declared ability appears in its parent chain. The
type parameters of the implemented declaration must still be in scope, in the
impl's signature and in its body.

Only the final `has bad: list[_T];` is expected to report E1065.
"""

import from typing { TypeVar }

glob _T = TypeVar("_T");

obj Box[T] {
    has item: T;

    def flatten(items: list[T | None]) -> list[T];
    def get_item -> T;
}

# Class type parameter `T` is in scope in the impl signature and body.
impl Box.flatten(items: list[T | None]) -> list[T] {
    out: list[T] = [];
    for it in items {
        if it is not None {
            out.append(it);
        }
    }
    return out;
}

# `T` is in scope in the body even though it is only bound by the owner.
impl Box.get_item -> T {
    held: T = self.item;
    return held;
}

# A module-level TypeVar bound by the impl's signature is usable in the body.
obj Bag {
    def assign_all(target: list[_T]) -> list[_T];
}

impl Bag.assign_all(target: list[_T]) -> list[_T] {
    copied: list[_T] = target;
    return copied;
}

# Negative guard: `_T` is not bound by this non-generic archetype.
obj Plain {
    has bad: list[_T];
}
