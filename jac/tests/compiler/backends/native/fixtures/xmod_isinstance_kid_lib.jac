"""A flat base with fields and methods, subclassed only by an importer.

Nothing here subclasses `RotatingEntry` or names it in an `isinstance`, so it
lays out without a vtable slot: `key` at slot 0.
"""

obj RotatingEntry {
    has key: int,
        hits: int = 0;

    def describe -> str {
        return f"entry {self.key}/{self.hits}";
    }

    def bump(n: int) {
        self.hits += n;
    }
}

def entry_key(e: RotatingEntry) -> int {
    return e.key;
}
