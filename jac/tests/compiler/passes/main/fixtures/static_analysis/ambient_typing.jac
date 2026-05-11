"""Curated typing constructs are ambient: callers should not need
`import from typing { ... }`. This fixture must produce no W2001 (undefined
name) or W1051 (unresolved type) warnings, and the generated Python must
include `from typing import ...` for every ambient name actually used."""

def take_callback(cb: Callable[[], None]) -> None {
    cb();
}

def map_keys(m: Mapping[str, int]) -> Sequence[str] {
    return list(m.keys());
}

def sum_iter(items: Iterable[int]) -> int {
    total = 0;
    for x in items {
        total = total + x;
    }
    return total;
}

obj Greeter(Protocol) {
    def greet() -> str;
}

with entry {
    take_callback(lambda { print("hi"); });
    print(map_keys({"a": 1}));
    print(sum_iter([1, 2, 3]));
}
