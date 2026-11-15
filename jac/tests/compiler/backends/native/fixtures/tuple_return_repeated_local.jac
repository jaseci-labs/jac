"""A local returned in two slots of one tuple is owned once per slot."""
obj Ident {
    has name: str = "";
}

def convert(n: str) -> tuple[Ident, (Ident | None), (str | None)] {
    ident = Ident(name=n);
    return (ident, ident, n);
}

glob kept: list[Ident] = [];
with entry {
    for i in range(200) {
        (left, reference, name) = convert(f"x{i}");
        kept.append(left);
        filler = Ident(name=f"filler{i}");
        if reference is None or name is None or filler.name == "" {
            print("missing");
        }
    }
    print(kept[0].name, kept[99].name, kept[199].name, len(kept));
}
