glob dropped: int = 0;

obj Item {
    has value: int;

    def drop {
        dropped += 1;
    }
}

def owned_input -> int {
    values: list[Item] = [];
    values.extend([Item(3), Item(4)]);
    return values[0].value + values[1].value;
}

def borrowed_input -> int {
    source = [Item(5), Item(6)];
    values: list[Item] = [];
    values.extend(source);
    return values[0].value + source[1].value;
}

def reversed_input -> int {
    source = [Item(7), Item(8)];
    values: list[Item] = [];
    values.extend(reversed(source));
    return values[0].value * 10 + source[0].value;
}

def comprehension_input -> int {
    values: list[Item] = [];
    values.extend([Item(i) for i in range(3)]);
    return values[0].value + values[1].value + values[2].value;
}

def empty_input -> int {
    values = [Item(9)];
    values.extend([]);
    return values[0].value;
}

def copied_receiver -> int {
    values = [Item(10)].copy();
    return values[0].value;
}

def popped_receiver -> int {
    item = [Item(11), Item(12)].pop();
    return item.value;
}

def existing_default -> int {
    values: dict[int, list[Item]] = {1: [Item(1)]};
    values.setdefault(1, [Item(2)]).append(Item(3));
    return values[1][0].value + values[1][1].value;
}

def missing_default -> int {
    values: dict[int, list[Item]] = {};
    values.setdefault(1, [Item(2)]).append(Item(3));
    return values[1][0].value + values[1][1].value;
}

def borrowed_default -> int {
    source = [Item(4)];
    values: dict[int, list[Item]] = {};
    selected = values.setdefault(1, source);
    selected.append(Item(5));
    return source[0].value + values[1][1].value;
}

def indexed_receiver(index: int) -> int {
    try {
        return [Item(4), Item(5)][index].value;
    } except IndexError {
        return -1;
    }
}

def borrowed_index(index: int) -> int {
    items = [Item(6), Item(7)];
    try {
        return items[index].value;
    } except IndexError {
        return items[0].value;
    }
}

obj Holder {
    has item: Item;
    has selected: Item { getter; }
}

impl Holder.selected.getter -> Item {
    return self.item;
}

def nested_receiver -> int {
    return Holder(Item(8)).item.value;
}

def property_receiver -> int {
    return Holder(Item(9)).selected.value;
}

def borrowed_field_write -> int {
    item = Item(10);
    item.value += 2;
    return item.value;
}

def drop_count -> int {
    return dropped;
}


glob text_builds: int = 0;
def make_text(value: int) -> str {
    text_builds += 1;
    return str(value);
}

def join_generator -> int {
    items = [Item(3)];
    text = ",".join(str(item.value) for item in items);
    return len(text);
}

def join_comprehension -> int {
    items = [Item(3)];
    text = ",".join([str(item.value) for item in items]);
    return len(text);
}

def list_generator -> int {
    items = [Item(3)];
    values = list(item.value for item in items);
    return sum(values);
}

def string_receiver_evaluations -> int {
    before = text_builds;
    assert make_text(3).startswith("3");
    return text_builds - before;
}

def bytes_receiver -> int {
    return len(make_text(3).encode().decode());
}

def chained_string_receiver -> int {
    return (" " + make_text(3) + " ").strip().count("3");
}

def borrowed_string_receiver -> int {
    value = make_text(3);
    assert value.startswith("3");
    return len(value);
}

obj OtherItem {
    has value: int;
}

def retyped_loop(mode: int) -> int {
    first = [Item(3)];
    second: list[OtherItem] = [OtherItem(4)] if mode == 1 else [];
    held: list[Holder] = [];
    result = 0;
    for item in first {
        held.append(Holder(item));
        result += item.value;
    }
    if mode < 2 {
        for item in second {
            result += item.value;
        }
    }
    return result + held[0].item.value;
}

def empty_retyped_loop -> int {
    return retyped_loop(0);
}

def populated_retyped_loop -> int {
    return retyped_loop(1);
}

def skipped_retyped_loop -> int {
    return retyped_loop(2);
}

def repeated_retyped_loop -> int {
    result = 0;
    for turn in range(3) {
        first = [Item(turn)];
        second: list[OtherItem] = [];
        held: list[Holder] = [];
        for item in first {
            held.append(Holder(item));
        }
        for item in second {
            result += item.value;
        }
        result += held[0].item.value;
    }
    return result;
}

def scalar_retyped_loop -> int {
    held: list[Holder] = [];
    for item in [Item(3)] {
        held.append(Holder(item));
    }
    for item in range(0) {
        return item;
    }
    return held[0].item.value;
}

def redeclared_local -> int {
    item: Item | None = Item(3);
    held = Holder(item);
    item: Item = Item(4);
    return held.item.value + item.value;
}

def retyped_parameter(item: Item) -> int {
    held = Holder(item);
    for item in [OtherItem(4)] {
        item.value += 1;
    }
    return held.item.value + item.value;
}

def borrowed_retyped_parameter -> int {
    item = Item(3);
    return retyped_parameter(item) + item.value;
}

obj OptionalHolder {
    has item: Item | None = None;
}

def identity_item(item: Item) -> Item {
    return item;
}

def owned_optional_field -> int {
    holder = OptionalHolder();
    holder.item = Item(3);
    return holder.item.value;
}

def borrowed_optional_field -> int {
    item = Item(4);
    holder = OptionalHolder();
    holder.item = item;
    holder.item = None;
    return item.value;
}

def aliased_optional_field -> int {
    holder = OptionalHolder(Item(5));
    if holder.item is None {
        return 0;
    }
    holder.item = identity_item(holder.item);
    holder.item = holder.item;
    return holder.item.value;
}

def overwritten_optional_field -> int {
    holder = OptionalHolder(Item(6));
    holder.item = Item(7);
    return holder.item.value;
}

def substring_text -> str {
    return "prefix" + make_text(3);
}

def borrowed_substring_lookup -> int {
    text = substring_text();
    part = text[0:3];
    table = {"pre": 7};
    result = 0;
    for _ in range(3) {
        if part in table {
            result += table[part];
        }
    }
    return result;
}

def borrowed_substring_receiver -> int {
    text = substring_text();
    part = text[3:];
    return int(part.startswith("fix"));
}

def owned_substring_prefix -> int {
    return int(substring_text()[0:3].startswith("pre"));
}

def owned_substring_suffix -> int {
    return int(substring_text()[3:].startswith("fix"));
}

def substring_values -> list[str] {
    text = substring_text();
    return [text[0:3], text[3:]];
}

def escaped_substring_container -> int {
    parts = substring_values();
    return int(parts[0] == "pre" and parts[1].startswith("fix"));
}

def compared_substring_loop -> int {
    text = substring_text();
    result = 0;
    for _ in range(3) {
        if text[0:3] == "pre" {
            result += 1;
        }
    }
    return result;
}

def boxed_substring -> object {
    text = substring_text();
    result: object = text[0:3];
    return result;
}

def returned_boxed_substring -> int {
    return int(str(boxed_substring()) == "pre");
}

def substring_builtin_identity -> int {
    return int(str(substring_text()[0:3]) == "pre");
}

def boxed_substring_container -> int {
    text = substring_text();
    values: list[object] = [text[0:3], text[3:]];
    return int(str(values[0]) == "pre" and str(values[1]).startswith("fix"));
}

def boxed_local_overwrite -> int {
    value: object = Item(2);
    value = Item(3);
    return (value as Item).value;
}

def boxed_borrowed_local -> int {
    item = Item(4);
    value: object = item;
    value = 0;
    return item.value + int(value);
}

def boxed_loop_local -> int {
    result = 0;
    for i in range(3) {
        value: object = Item(i);
        result += (value as Item).value;
    }
    return result;
}

def box_item(item: Item) -> object {
    value: object = item;
    return value;
}

def returned_boxed_local -> int {
    value = box_item(Item(6));
    return (value as Item).value;
}

def boxed_consume_loop(values: list[object]) -> int {
    result = 0;
    for value in values {
        result += int(isinstance(value, Item));
    }
    return result;
}

def boxed_loop_binding -> int {
    value = 3;
    items: list[object] = [Item(value), Item(value + 1)];
    before = dropped;
    boxed_consume_loop(items);
    return int(dropped == before);
}

def boxed_consume_comprehension(values: list[object]) -> int {
    return sum([int(isinstance(value, Item)) for value in values]);
}

def boxed_comprehension_binding -> int {
    value = 3;
    items: list[object] = [Item(value), Item(value + 1)];
    before = dropped;
    boxed_consume_comprehension(items);
    return int(dropped == before);
}

def boxed_capture(value: object) -> int {
    match value {
        case bound:
            return int(isinstance(bound, Item));

    }
}

def boxed_match_binding -> int {
    value = 3;
    item = Item(value);
    before = dropped;
    boxed_capture(item);
    return int(dropped == before);
}

def boxed_unpack(items: tuple[object, object]) -> int {
    (first, second) = items;
    return int(isinstance(first, Item)) + int(isinstance(second, Item));
}

def boxed_tuple_binding -> int {
    value = 3;
    item = Item(value);
    other = Item(value + 1);
    items: tuple[object, object] = (item, other);
    before = dropped;
    boxed_unpack(items);
    return int(dropped == before);
}

def boxed_rebind(value: object) -> int {
    value = Item(8);
    return int(isinstance(value, Item));
}

def boxed_parameter_binding -> int {
    value = 3;
    item = Item(value);
    before = dropped;
    boxed_rebind(item);
    return int(dropped == before + 1);
}

def boxed_walrus(value: object) -> int {
    return int(isinstance((bound := value), Item));
}

def boxed_walrus_binding -> int {
    value = 3;
    item = Item(value);
    before = dropped;
    boxed_walrus(item);
    return int(dropped == before);
}


def boxed_dict_items(values: dict[int, object]) -> int {
    result = 0;
    for (key, value) in values.items() {
        result += key * int(isinstance(value, Item));
    }
    return result;
}

def boxed_dict_binding -> int {
    items: dict[int, object] = {1: Item(3), 2: Item(4)};
    before = dropped;
    result = boxed_dict_items(items);
    return result + int(dropped == before);
}

def boxed_tuple_make(value: object) -> tuple[object, object] {
    return (value, value);
}

def boxed_tuple_escape -> int {
    item = Item(3);
    before = dropped;
    pair = boxed_tuple_make(item);
    result = boxed_unpack(pair);
    return result + int(dropped == before);
}

def boxed_tuple_swap -> int {
    first: object = Item(3);
    second: object = Item(4);
    before = dropped;
    (first, second) = (second, first);
    return int(isinstance(first, Item))
        + int(isinstance(second, Item))
        + int(dropped == before);
}


def boxed_walrus_parameter(value: object, replace: bool) -> int {
    if replace {
        return int(isinstance((value := Item(8)), Item));
    }
    return int(isinstance(value, Item));
}

def boxed_walrus_parameter_binding -> int {
    item = Item(3);
    before = dropped;
    result = boxed_walrus_parameter(item, False);
    if dropped != before {
        return 0;
    }
    result += boxed_walrus_parameter(item, True);
    return result + int(dropped == before + 1);
}


def boxed_nested_parameter_binding -> int {
    def consume(value: object) -> int {
        value = Item(8);
        return int(isinstance(value, Item));
    }
    item = Item(3);
    before = dropped;
    result = consume(item);
    return result + int(dropped == before + 1);
}
