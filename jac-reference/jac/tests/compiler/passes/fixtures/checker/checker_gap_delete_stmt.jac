"""Gap #42: DeleteStmt target not type-checked.

No exit_delete_stmt handler exists. The target expression of del
is never type-evaluated, so accessing nonexistent attributes or
using wrong types in delete targets goes unchecked.

Expected errors:
  1. Deleting nonexistent attribute
  2. Deleting with wrong index type on dict
  3. Deleting nonexistent nested attribute
  4. Deleting nonexistent attribute on outer object
"""

obj Container {
    has name: str = "test",
        value: int = 0,
        items: dict[str, int] = {};
}

obj Outer {
    has inner: Container = Container();
}

with entry {
    c = Container();

    # Case 1: Deleting nonexistent attribute
    del c.nonexistent;           # Error: no such attribute on Container

    # Case 2: Deleting with wrong index type on dict (should accept str keys)
    c.items["key"] = 1;
    del c.items[42];             # Error: int key on dict[str, int]

    # Case 3: Nested nonexistent attribute
    o = Outer();
    del o.inner.missing_attr;    # Error: no such attribute on Container

    # Case 4: Deleting nonexistent attribute on outer
    del o.nonexistent.something; # Error: no such attribute on Outer

    # --- Cases that SHOULD be valid ---
    del c.name;                  # Ok: attribute exists
    del c.items["key"];          # Ok: str key on dict[str, int]
}
