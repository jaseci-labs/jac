obj Item {
    has v: int = 0;
}

glob TABLE: list[Item | None] = [];

def pick(i: int) -> (Item | None) {
    return TABLE[i];
}

with entry {
    TABLE.append(Item(v=1));
    TABLE.append(None);
    TABLE.append(Item(v=7));
    filler = [Item(v=99) for _ in range(8)];
}

glob seen: list[str] = [];

with entry {
    for it in TABLE {
        seen.append(str(it.v) if it is not None else "-");
    }
    first = pick(0);
    print(",".join(seen), first.v if first is not None else -1, len(filler));
}
