obj NameAtom { has sym_name: str = ""; }
obj OtherPattern { has code: int = 0; }
obj KeyValPair {
    has key: NameAtom | OtherPattern = NameAtom(),
        val: int = 0;
}

def collect_names(items: list[NameAtom | OtherPattern]) -> list[str] {
    return [x.sym_name for x in items if isinstance(x, NameAtom)];  # ok: x narrowed to NameAtom
}

def collect_key_names(pairs: list[KeyValPair]) -> list[str] {
    return [
        x.key.sym_name  # ok: x.key narrowed to NameAtom
        for x in pairs
        if isinstance(x.key, NameAtom)
    ];
}

def collect_both(
    items: list[NameAtom | OtherPattern],
    pairs: list[KeyValPair]
) -> list[str] {
    direct = [x.sym_name for x in items if isinstance(x, NameAtom)];  # ok: x narrowed
    from_pairs = [p.key.sym_name for p in pairs if isinstance(p.key, NameAtom)];  # ok: p.key narrowed
    result: list[str] = [];
    result.extend(direct);
    result.extend(from_pairs);
    return result;
}

def collect_compound(items: list[NameAtom | OtherPattern]) -> list[str] {
    return [
        x.sym_name  # ok: x narrowed to NameAtom via compound AND filter
        for x in items
        if isinstance(x, NameAtom) and len(x.sym_name) > 0
    ];
}
