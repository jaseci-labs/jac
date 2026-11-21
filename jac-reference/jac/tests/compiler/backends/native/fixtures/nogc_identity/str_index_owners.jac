"""A character taken by indexing a string comes from the static per-byte
cache, so every owner it reaches gets a copy: a field store, `super.init`
into a field-derived initializer, and a list. Replacing or dropping each
owner then frees only text it owns."""

obj Letter {
    has c: str = "";
}

obj LetterChild(Letter) {
    def init(seed: &str) {
        super.init(seed[0]);
    }
}

def run -> int {
    total = 0;
    for i in range(40) {
        seed = f"abc{i}";
        lc = LetterChild(&seed);
        p = Letter();
        p.c = seed[1];
        xs: list[str] = [];
        xs.append(seed[2]);
        if i < 2 {
            print(lc.c, p.c, xs);
        }
        total += len(lc.c) + len(p.c) + len(xs[0]) + i;
        lc.c = "z";
        p.c = "y";
    }
    return total;
}

with entry {
    print(run());
}
