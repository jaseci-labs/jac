"""Collection growth preserves scalar values and element ownership."""

glob drops: int = 0;

obj Item {
    has value: int;

    def drop {
        drops += 1;
    }
}

def integers -> int {
    values: list[int] = [];
    for i in range(256) {
        values.append(i);
    }
    return sum(values);
}

def references -> int {
    drops = 0;
    values: list[Item] = [];
    for i in range(128) {
        values.append(Item(value=i));
    }
    total = 0;
    for value in values {
        total += value.value;
    }
    return total;
}

def mixed -> int {
    drops = 0;
    values: list[any] = [];
    for i in range(64) {
        values.append(Item(value=i));
        values.append(i);
    }
    total = 0;
    for value in values {
        if isinstance(value, Item) {
            total += value.value;
        } elif isinstance(value, int) {
            total += value;
        }
    }
    return total;
}

def bytes_growth -> int {
    values = bytearray();
    for i in range(512) {
        values.append(i % 256);
    }
    return len(values) + values[255] + values[511];
}

def read_drops -> int {
    return drops;
}
