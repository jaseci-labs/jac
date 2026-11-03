obj Item {
    has name: str = "";
}

obj Holder {
    has items: (Sequence[Item] | None) { getter; }
}

impl Holder.items.getter -> (Sequence[Item] | None) {
    return [Item(name="a")];
}

def names(h: Holder) -> list[str] {
    got = list(h.items or []);
    return [i.name for i in got];
}
