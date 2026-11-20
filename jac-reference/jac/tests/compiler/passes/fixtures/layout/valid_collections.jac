"""Fixture: obj with typed collection fields."""

obj WithList {
    has items: list[int];
}

obj WithDict {
    has entries: dict[str, int];
}

obj WithSet {
    has tags: set[int];
}
