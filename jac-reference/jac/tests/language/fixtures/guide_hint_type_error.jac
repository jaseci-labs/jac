"""Fixture: a type error that should make `jac check` point at the jac-types guide."""

with entry {
    count: int = "not a number";
    print(count);
}
