glob destroyed: int = 0;

obj Item {
    has value: int;

    def drop {
        destroyed += 1;
    }
}

def items -> tuple[Item, Item] {
    return (Item(4), Item(7));
}

def scalars -> int {
    numbers = list((2, 3, 5));
    fractions = list((1.5, 2.5));
    words = list(("ab", "cde"));
    mixed = list((1, "abc", 2));
    total = numbers[0] + numbers[1] + numbers[2];
    total += int(fractions[0] + fractions[1]);
    total += len(words[0]) + len(words[1]);
    for value in mixed {
        if isinstance(value, int) {
            total += value;
        } elif isinstance(value, str) {
            total += len(value);
        }
    }
    return total;
}

def fresh_objects -> int {
    values = list((Item(2), Item(8)));
    return values[0].value + values[1].value;
}

def returned_objects -> int {
    values = list(items());
    return values[0].value + values[1].value;
}

def drops -> int {
    return destroyed;
}

with entry {
    print(scalars());
    print(fresh_objects());
    print(returned_objects());
    print(drops());
}
