glob dropped: int = 0;

obj Item {
    has value: int;

    def drop {
        dropped += 1;
    }
}

def maybe_items(kind: int) -> list[Item] | None {
    if kind == 0 {
        return None;
    }
    if kind == 1 {
        return [];
    }
    return [Item(3), Item(4)];
}

def optional_or(kind: int) -> int {
    values = maybe_items(kind) or [Item(5)];
    return values[0].value;
}

def optional_and(kind: int) -> int {
    values = maybe_items(kind) and [Item(5)];
    return len(values or []);
}

def optional_pair(kind: int) -> int {
    values = maybe_items(kind) or maybe_items(2);
    return len(values or []);
}

def borrowed_or(kind: int) -> int {
    source = maybe_items(kind);
    values = source or [Item(5)];
    return values[0].value;
}

obj Holder {
    has stored: list[Item] | None;
    has selected: list[Item] | None { getter; }
}

impl Holder.selected.getter -> list[Item] | None {
    return self.stored;
}

def property_or(kind: int) -> int {
    holder = Holder(maybe_items(kind));
    values = holder.selected or [Item(5)];
    return values[0].value;
}

def dict_get(key: int) -> int {
    value = {1: Item(3)}.get(key, Item(4));
    return value.value;
}

def dict_get_borrowed(key: int) -> int {
    values = {1: Item(3)};
    value = values.get(key, Item(4));
    return value.value + values[1].value;
}

def dict_optional_get(key: int) -> int {
    value = {1: Item(3)}.get(key);
    return value.value if value is not None else -1;
}

def dict_list_get(key: int) -> int {
    value = {1: [Item(3)]}.get(key, [Item(4)]);
    return value[0].value;
}

def dict_string_get(key: int) -> int {
    value = {1: "a" + str(key)}.get(key, "bc" + str(key));
    assert value == ("a1" if key == 1 else "bc0");
    return len(value);
}

def dict_optional_string(key: int) -> int {
    value = {1: "a" + str(key)}.get(key);
    if value is not None {
        assert value == "a1";
    }
    return len(value) if value is not None else -1;
}

def dropped_count -> int {
    return dropped;
}
