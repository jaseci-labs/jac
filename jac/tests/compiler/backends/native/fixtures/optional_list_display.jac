"""List displays preserve absent pointer elements instead of unwrapping them."""
obj Item {
    has value: int;
}

def from_optionals(first: Item | None, second: Item | None) -> list[Item | None] {
    return [first, second];
}

def:pub optional_list_check -> int {
    item = Item(value=42);
    values = from_optionals(None, item);
    if values[0] is not None {
        return 1;
    }
    if values[1] is not item {
        return 2;
    }
    reverse = from_optionals(item, None);
    if reverse[0] is not item or reverse[1] is not None {
        return 3;
    }
    absent: Item | None = None;
    local: list[Item | None] = [absent, item, absent];
    if local[0] is not None or local[1] is not item or local[2] is not None {
        return 4;
    }
    return 0;
}
