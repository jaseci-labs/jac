"""Fixture: locals in nested blocks of an impl body that share a name with
the archetype's method or `has` field.

Each of `changed`, `grid`, `opened` and `count` is first assigned inside a
`for` or `if` body, with a type other than the member's. They are locals of
the method; the members are reached through `self`. A parameter reassigned
inside a block is still the parameter.
"""

obj Shelf {
    has grid: float = 8.0,
        opened: dict[str, bool] = {},
        count: int = 0;

    def changed;
    def tally(words: list[str]) -> int;
    def named(prefix: str) -> list[str];
}

impl Shelf.changed {
    self.count += 1;
}

impl Shelf.tally(words: list[str]) -> int {
    total = 0;
    for word in words {
        changed = len(word);
        grid = word.upper();
        opened = [changed];
        total += changed + len(grid) + len(opened);
        self.changed();
    }
    if total > 0 {
        count = "many";
        total += len(count);
    }
    return total + int(self.grid) + self.count;
}

impl Shelf.named(prefix: str) -> list[str] {
    found: list[str] = [];
    for index in range(2) {
        prefix = prefix + str(index);
        found.append(prefix);
    }
    return found;
}

with entry {
    shelf = Shelf();
    print(shelf.tally(["ab", "cde"]), shelf.count, shelf.grid, shelf.opened);
    print(shelf.named("p"));
}
