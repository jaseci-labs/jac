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

def none_predicates(kind: int) -> int {
    return int(maybe_items(kind) is None)
        + int(None is maybe_items(kind))
        + int(maybe_items(kind) == None)
        + int(None == maybe_items(kind))
        + int(maybe_items(kind) is not None)
        + int(None is not maybe_items(kind))
        + int(maybe_items(kind) != None)
        + int(None != maybe_items(kind));
}

def predicate_branch(kind: int) -> int {
    before = dropped;
    if maybe_items(kind) is not None {
        return dropped - before;
    }
    return -1;
}

def predicate_chain(kind: int) -> int {
    return int(maybe_items(kind) is not None is not maybe_items(kind));
}

def type_predicate(kind: int) -> int {
    return int(isinstance(maybe_items(kind), list));
}

def borrowed_predicates(kind: int) -> int {
    value = maybe_items(kind);
    before = dropped;
    if value is not None and isinstance(value, list) {
        assert dropped == before;
        return len(value);
    }
    return -1;
}

def predicate_binding(kind: int) -> int {
    if (values := maybe_items(kind)) is not None {
        return len(values);
    }
    return -1;
}

def predicate_loop(kind: int) -> int {
    before = dropped;
    for i in range(4) {
        if maybe_items(kind) is not None {
            assert dropped - before == (i + 1) * (2 if kind == 2 else 0);
        }
    }
    return dropped - before;
}

def failing_operand -> list[Item] | None {
    raise ValueError("operand");
}

def predicate_unwind(kind: int) -> int {
    return int(maybe_items(kind) is failing_operand());
}

def catch_predicate_unwind(kind: int) -> int {
    before = dropped;
    try {
        return predicate_unwind(kind);
    } except ValueError {
        return dropped - before;
    }
}

def catch_predicate_operand(kind: int) -> int {
    before = dropped;
    try {
        return int(maybe_items(kind) is failing_operand());
    } except ValueError {
        return dropped - before;
    }
}

def catch_inside_owned_loop(kind: int) -> int {
    total = 0;
    for item in [Item(3), Item(4)] {
        try {
            total += int(maybe_items(kind) is failing_operand());
        } except ValueError {
            total += item.value;
        }
    }
    return total;
}

def dynamic_item(kind: int) -> Item | int | str {
    if kind == 0 {
        return 7;
    }
    if kind == 1 {
        return "word";
    }
    return Item(5);
}

def dynamic_none(kind: int) -> int {
    return int(dynamic_item(kind) is not None);
}

def dynamic_type(kind: int) -> int {
    return int(isinstance(dynamic_item(kind), Item));
}

def membership_temporaries(kind: int) -> int {
    item = Item(kind);
    return int(item in [item, Item(3)]) + int(Item(4) not in [item]);
}
