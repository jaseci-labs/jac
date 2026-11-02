"""Nested tuple targets in a `for` header and in unpacking.

`for (i, (a, b)) in enumerate(pairs)` inside a function used to compile and
leave `a` and `b` unbound: the inner tuple target was taken for a name. Every
level is bound here, over a list, `enumerate` and `dict.items()`, with an
object inside so reference counting is exercised across iterations."""
obj Tag {
    has label: str = "";
}

def pairs_of(n: int) -> list[tuple[str, tuple[Tag, int]]] {
    return [(f"k{i}", (Tag(label=f"t{i}"), i)) for i in range(n)];
}

def named(names: list[str]) -> str {
    bound: list[tuple[str, bool]] = [(n, len(n) > 1) for n in names];
    out = "";
    for (i, (pname, long)) in enumerate(bound) {
        out += f"{i}:{pname}:{long} ";
    }
    return out;
}

def walk(d: dict[str, tuple[int, str]]) -> str {
    out = "";
    for (k, (num, word)) in d.items() {
        out += f"{k}={num}/{word} ";
    }
    return out;
}

with entry {
    total = 0;
    for rep in range(300) {
        for (i, (key, (tag, num))) in enumerate(pairs_of(3)) {
            if tag.label == f"t{num}" and key == f"k{i}" {
                total += num + i;
            }
        }
    }
    print("total", total);
    print(named(["a", "bb"]));
    print(walk({"a": (1, "one"), "b": (2, "two")}));
    for ((a, b), c) in [((1, 2), 3), ((4, 5), 6)] {
        print(a, b, c);
    }
}
