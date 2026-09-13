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
