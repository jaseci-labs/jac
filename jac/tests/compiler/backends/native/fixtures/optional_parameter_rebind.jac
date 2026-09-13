"""Rebinding an optional parameter must not consume the caller's value."""
glob drops: int = 0;
obj Item {
    has value: int;

    def drop {
        drops += 1;
    }
}

def replace(value: Item | None) {
    value = Item(value=2);
    value = None;
}

def clear(value: dict[str, int] | None) {
    value = None;
}

def:pub optional_parameter_check -> int {
    item = Item(value=42);
    before = drops;
    replace(item);
    if drops != before + 1 {
        return 1;
    }
    if item.value != 42 {
        return 2;
    }
    replace(None);
    if drops != before + 2 {
        return 3;
    }
    values = {"answer": 42};
    clear(values);
    clear(values);
    if values["answer"] != 42 {
        return 4;
    }
    return 0;
}
