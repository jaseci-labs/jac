"""Boolean comparison results share the declared tuple storage layout."""
obj Item {
    has name: str;
}
def flags(item: Item, member: bool) -> tuple[Item, bool, bool, bool, bool] {
    matched = member or item.name in ("annotation", "returns");
    return (item, False, True, False, matched);
}

def:pub tuple_bool_check -> int {
    item = Item(name="ordinary");
    values: list[tuple[Item, bool, bool, bool, bool]] = [];
    for i in range(20) {
        matched = i in (2, 4, 6);
        values.append((item, False, True, False, matched));
    }
    for i in range(20) {
        (got, first, second, third, last) = values[i];
        if got is not item or first or not second or third {
            return 1;
        }
        if last != (i in (2, 4, 6)) {
            return 2;
        }
    }
    (got, first, second, third, last) = flags(item, False);
    if last {
        return 3;
    }
    return 0;
}
