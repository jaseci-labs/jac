"""`==` between an untyped value and an object whose class defines `__eq__`.

A value read out of a `dict[str, any]` compared against such an object used
to compare identity, so two equal objects read as different. The object's
`__eq__` is asked, as the Python tier does; an untyped value that is not an
instance of the class still compares unequal."""
obj Ty {
    has name: str = "";

    def __eq__(other: object) -> bool {
        return isinstance(other, Ty) and other.name == self.name;
    }
}

obj Plain {
    has n: int = 0;
}

def probe(h: dict[str, any]) -> str {
    kt = h.get("key", h.get("elem"));
    out = "";
    if kt != Ty(name="i8p") {
        out += "ne ";
    } else {
        out += "eq ";
    }
    et = h["elem"];
    if et == Ty(name="i64") {
        out += "elem-eq ";
    }
    if Ty(name="i64") == et {
        out += "rev-eq ";
    }
    typed: Ty = h["elem"];
    if typed == Ty(name="i64") {
        out += "typed-eq";
    }
    return out;
}

with entry {
    print(probe({"key": Ty(name="i8p"), "elem": Ty(name="i64"), "n": 3}));
    print(probe({"elem": Ty(name="i64")}));
    keep = Ty(name="a");
    total = 0;
    for i in range(400) {
        h: dict[str, any] = {"t": keep, "p": Plain(n=i), "s": "a", "n": 3};
        if h["t"] == Ty(name="a") {
            total += 1;
        }
        if h["p"] == Ty(name="a") or h["s"] == Ty(name="a") or h["n"] == Ty(name="a") {
            total += 100;
        }
        if Ty(name="b") != h["t"] {
            total += 1;
        }
    }
    print("total", total, keep.name);
}
