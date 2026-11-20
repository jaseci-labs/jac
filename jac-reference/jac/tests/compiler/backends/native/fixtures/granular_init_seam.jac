"""Fixture: a user `init` body's capability violation demotes that constructor.

`Tally.init` imports `collections`. The class layout still emits and
`Tally.total` still lowers; the point of the fixture is that the
initializer becomes a seam of its own instead of costing the module its
IR.
"""

obj Tally {
    has n: int = 0;

    def init(seed: int) {
        import collections;
        self.n = seed + len(collections.OrderedDict());
    }

    def total(x: int) -> int {
        return x + 1;
    }
}

obj Bystander {
    def keep(x: int) -> int {
        return x - 1;
    }
}

with entry {
    print(Bystander().keep(9));
}
