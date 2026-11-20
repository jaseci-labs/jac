obj Base {
    has label: str = "base";
}

obj Leaf(Base) {
    has name: str = "leaf";
}

def kind(value: any) -> str {
    if isinstance(value, Leaf) {
        return "leaf:" + value.name;
    }
    if isinstance(value, Base) {
        return "base:" + value.label;
    }
    if isinstance(value, str) {
        return "str:" + value;
    }
    return "other";
}

def by_enumerate(items: list[Base]) -> list[str] {
    out: list[str] = [];
    for (i, item) in enumerate(items) {
        out.append(f"{i}:{kind(item)}");
    }
    return out;
}

def by_zip(items: list[Base], names: list[str]) -> list[str] {
    out: list[str] = [];
    for (item, name) in zip(items, names) {
        out.append(kind(item) + "/" + kind(name));
    }
    return out;
}

def by_items(table: dict[str, Base]) -> list[str] {
    out: list[str] = [];
    for (key, item) in table.items() {
        out.append(key + "=" + kind(item));
    }
    return out;
}

def boxed(items: list[Base]) -> list[any] {
    held: list[any] = [];
    for (i, item) in enumerate(items) {
        held.append(item);
    }
    return held;
}

with entry {
    items: list[Base] = [Leaf(name="a"), Base(label="b"), Leaf(name="c", label="x")];
    print(by_enumerate(items));
    print(by_zip(items, ["p", "q", "r"]));
    print(by_items({"k1": items[0], "k2": items[1]}));
    print([kind(v) for v in boxed(items)]);
}
