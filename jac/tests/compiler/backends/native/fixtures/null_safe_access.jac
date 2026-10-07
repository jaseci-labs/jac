"""`a?.b` on the native tier: `None` for a `None` receiver, the read otherwise.

Every result kind is here because each merges differently: a reference and an
option can already say `None`, an integer, float or bool comes back as an
option, and an attribute only a subclass has reads as `None` on an instance
of the base. The loop at the end runs owned receivers (a call result) through
both arms so a missing or doubled release shows under reference counting."""
obj A {
    has x: int = 1,
        nxt: (A | None) = None,
        name: str = "n",
        ratio: float = 0.5,
        flag: bool = True,
        items: list[int] = [];
}

obj B(A) {
    has extra: int = 7,
        label: str = "b";
}

def make(n: int) -> (A | None) {
    if n == 0 {
        return None;
    }
    return A(x=n, name="made");
}

def show_int(a: (A | None)) -> str {
    v = a?.x;
    return "none" if v is None else str(v);
}

def show_name(a: (A | None)) -> str {
    v = a?.name;
    if v == "made" {
        return "made!";
    }
    return "none" if v is None else v;
}

def show_ratio(a: (A | None)) -> str {
    v = a?.ratio;
    return "none" if v is None else str(v);
}

def flagged(a: (A | None)) -> bool {
    if a?.flag {
        return True;
    }
    return False;
}

def deep(a: (A | None)) -> str {
    return "y" if a?.nxt?.nxt is not None else "n";
}

def deep_x(a: (A | None)) -> int {
    v = a?.nxt?.x;
    if v is None {
        return -1;
    }
    return v;
}

def extra_of(a: A) -> str {
    v = a?.extra;
    return "none" if v is None else str(v);
}

def label_of(a: (A | None)) -> str {
    v = a?.label;
    return "none" if v is None else str(v);
}

def has_extra(a: A) -> bool {
    return a?.extra is not None;
}

def first(xs: (list[int] | None)) -> str {
    v = xs?[0];
    return "none" if v is None else str(v);
}

def count(a: (A | None)) -> int {
    n = a?.items;
    if n is None {
        return -1;
    }
    return len(n);
}

with entry {
    full = A(x=5, nxt=A(x=6, nxt=A(x=7)));
    print("int", show_int(None), show_int(full));
    print(
        "name", show_name(None), show_name(full), show_name(make(3)), show_name(make(0))
    );
    print("ratio", show_ratio(None), show_ratio(full));
    print("flag", flagged(None), flagged(full), flagged(A(flag=False)));
    print(
        "deep",
        deep(None),
        deep(A()),
        deep(full),
        deep_x(None),
        deep_x(A()),
        deep_x(full)
    );
    print("extra", extra_of(A()), extra_of(B()), has_extra(A()), has_extra(B()));
    print("label", label_of(None), label_of(A()), label_of(B(label="bee")));
    print("count", count(None), count(A(items=[1, 2, 3])));
    print("index", first(None), first([4, 5]));
    print("temp", make(0)?.x is None, make(4)?.x);
    total = 0;
    for i in range(500) {
        if make(i % 2)?.name == "made" {
            total += 1;
        }
        if full?.nxt?.nxt is not None {
            total += 1;
        }
    }
    print("total", total, full.x);
}
