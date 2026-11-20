"""An object owns its `str` and `bytes` fields and an owned container its
string elements: a store copies in a borrowed or literal value and moves a
fresh one, replacing a field or an element frees the value it held, and the
drop frees the last. Method calls on a temporary string free the temporary."""

obj Tagged {
    has name: str,
        tag: str = "t",
        blob: bytes = b"";
}

obj Labeled(Tagged) {
    has note: str = "";
}

def build(i: int, seed: &str) -> int {
    a = Tagged(name=f"n{i}");
    b = Tagged(name="literal", blob=f"b{i}".encode());
    s = f"moved{i}";
    c = Labeled(name=s, note=seed);
    a.name = f"m{i}";
    a.tag = "lit";
    a.tag = a.tag + f"{i}";
    b.blob = b"xy";
    c.note = c.name + "";
    return len(a.name) + len(a.tag) + len(b.name) + len(b.blob) + len(c.note);
}

def fill(i: int) -> int {
    xs: list[str] = list();
    xs.append(f"a{i}");
    xs.append("lit");
    xs[0] = f"b{i}";
    ys = [f"c{i}", "d"];
    ys[1] = "e";
    d: dict[str, str] = {};
    d[f"k{i}"] = f"v{i}";
    d[f"k{i}"] = "again";
    d["lit"] = "x";
    e = {f"p{j}": f"q{j}" for j in range(3)};
    s: set[str] = set();
    s.add(f"x{i}");
    s.add(f"x{i}");
    s.add("lit");
    return len(xs) + len(ys[0]) + len(d) + len(e) + len(s);
}

def temps(i: int) -> int {
    return len(f"u{i}".upper()) + len(f"e{i}".encode()) + len(f" s{i} ".strip());
}

def run -> int {
    seed = f"se{'ed'}";
    total = 0;
    for i in range(30) {
        total += build(i, &seed) + fill(i) + temps(i);
    }
    return total;
}

with entry {
    print(run());
}
