"""Index, slice and iterate multibyte text under an RC debug build; the
live-object dump at exit must hold no leaked character."""

def each(s: str) -> Iterator[str] {
    for ch in s {
        yield ch;
    }
}

def run -> int {
    total = 0;
    words = ["héllo", "日本語", "🙂x🙂", "abc"];
    for k in range(50) {
        for w in words {
            for ch in w {
                total += len(ch);
            }
            v = w[1:];
            for ch in v {
                total += len(ch);
            }
            for i in range(len(w)) {
                c = w[i];
                total += len(c);
            }
            for i in range(len(v)) {
                total += len(v[i]);
            }
            it = iter(w);
            total += len(next(it));
            for ch in each(w) {
                total += len(ch);
            }
            kept = [ch for ch in w];
            total += len("".join(kept));
            total += len(w[::-1]) + len(w.strip("é"));
        }
    }
    return total;
}

with entry {
    print(run());
    __rc_collect_cycles();
    __rc_debug_enable();
}
