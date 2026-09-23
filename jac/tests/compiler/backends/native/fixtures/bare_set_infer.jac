"""An empty `set()` takes its element type from the adds that fill it."""

def key_of(i: int) -> (str | None) {
    return None if i % 3 == 0 else f"k{i % 4}";
}

def annotated_bare -> list[str] {
    seen: set = set();
    for i in range(10) {
        key = key_of(i);
        if key is not None {
            seen.add(key);
        }
    }
    return sorted(seen);
}

def unannotated(words: list[str]) -> int {
    found = set();
    for w in words {
        found.add(w.upper());
    }
    return len(found);
}

def merged(extra: set[str]) -> list[str] {
    s = set();
    s.add("a");
    s.update(extra);
    s |= {"z"};
    return sorted(s);
}

def counts -> list[int] {
    nums = set();
    for i in range(6) {
        nums.add(i % 3);
    }
    return sorted(nums);
}

with entry {
    print(annotated_bare());
    print(unannotated(["a", "b", "A"]));
    print(merged({"b", "a"}));
    print(counts(), "k1" in set(annotated_bare()));
}
