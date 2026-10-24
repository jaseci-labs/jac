"""`super.init(...)` into the initializer an `obj` derives from its fields.
Every argument is owned before any field changes: a later argument that reads
a field an earlier one replaces keeps the text that field held rather than
memory the store freed, and a single-use local moves into its field without a
second copy that would leak the first."""

obj Named {
    has first: str,
        second: str;
}

obj NamedChild(Named) {
    def init(seed: &str) {
        self.first = seed + "-old";
        super.init(seed + "-new", self.first);
    }
}

obj Single {
    has label: str;
}

obj SingleChild(Single) {
    def init(seed: &str) {
        text = seed + "!";
        super.init(text);
    }
}

def run -> int {
    total = 0;
    for i in range(40) {
        seed = f"seed{i}";
        nc = NamedChild(&seed);
        sc = SingleChild(&seed);
        if i < 3 {
            print(nc.first, nc.second, sc.label);
        }
        total += len(nc.first) + len(nc.second) + len(sc.label);
    }
    return total;
}

with entry {
    print(run());
}
