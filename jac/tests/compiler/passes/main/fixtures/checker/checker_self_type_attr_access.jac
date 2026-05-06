"""Test: attribute access on a `Self`-typed value resolves via the enclosing class.

When a method returns `Self` (e.g. `object.__new__(self.__class__)`), the result
is typed as the `Self` TypeVar. Member access on that value should look up
attributes on the enclosing class — Pyright treats `Self` as implicitly bound to
the class that defines the method.

Reproducer mirrors `Anchor.make_stub` in jac/jaclang/jac0core/impl/archetype.impl.jac
where `unloaded.id = self.id;` previously errored with E1031 ("Cannot access
attribute 'id' for type 'Self'").
"""

obj Anchor {
    has id: int = 0,
        name: str = "";

    def make_stub -> Anchor;
    def get_id_via_stub -> int;
}

impl Anchor.make_stub -> Anchor {
    # `object.__new__(self.__class__)` returns Self.
    # Both reading and writing attributes through `unloaded` should resolve
    # against the enclosing class (Anchor) rather than failing as if Self
    # were an opaque unbounded TypeVar.
    unloaded = object.__new__(self.__class__);
    unloaded.id = self.id;          # write: must succeed
    unloaded.name = self.name;      # write: must succeed
    return unloaded;
}

impl Anchor.get_id_via_stub -> int {
    # Read access through Self should also resolve, with the right type.
    unloaded = object.__new__(self.__class__);
    unloaded.id = self.id;
    x: int = unloaded.id;           # read: must type as int (not Unknown)
    return x;
}
