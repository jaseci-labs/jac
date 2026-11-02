"""`set` and `frozenset` over ranges, tuples and dicts of numbers, as in CPython."""

obj Keeper {
    has count: int = 3,
        kept: dict[int, set[int]] = {};

    def look(everything: bool) -> int {
        seen: set[int] = set();
        if everything {
            seen = set(range(1, self.count + 1));
        } else {
            for i in range(self.count) {
                seen.add(i);
            }
        }
        found = len(seen);
        self.kept[1 if everything else 0] = seen;
        return found;
    }
}

def from_range(count: int) -> list[int] {
    seen = set(range(1, count + 1));
    stepped = set(range(10, 0, -3));
    frozen = frozenset(range(count));
    return [
        len(seen),
        sum(sorted(seen)),
        len(stepped),
        sorted(stepped)[0],
        len(frozen)
    ];
}

def from_tuple -> list[int] {
    seen = set((4, 2, 2, 9, 4));
    return sorted(seen);
}

def from_dict -> list[int] {
    table: dict[int, str] = {7: "a", 3: "b", 5: "c"};
    seen = set(table);
    return sorted(seen);
}

def from_floats -> list[float] {
    seen = set((1.5, 2.5, 1.5, -0.5));
    return sorted(seen);
}

def from_empty(count: int) -> int {
    return len(set(range(count, count))) + len(frozenset(range(0)));
}

with entry {
    keeper = Keeper();
    print(keeper.look(True), keeper.look(False), sorted(keeper.kept[1]));
    print(from_range(5), from_range(0));
    print(from_tuple(), from_dict());
    print(from_floats(), from_empty(4));
}
