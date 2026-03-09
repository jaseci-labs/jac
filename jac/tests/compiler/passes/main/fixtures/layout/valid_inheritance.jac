"""Fixture: obj inheritance (child inherits parent fields)."""

obj Parent {
    has parent_field: int;
}

obj Child(Parent) {
    has child_field: int;
}
