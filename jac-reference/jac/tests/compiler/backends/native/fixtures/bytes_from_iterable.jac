"""`bytes` and `bytearray` over ranges and tuples of ints, as in CPython."""

def from_range(count: int) -> list[int] {
    whole = bytes(range(count));
    stepped = bytes(range(250, 256, 2));
    grown = bytearray(range(3));
    grown.append(9);
    return [
        len(whole),
        whole[count - 1],
        len(stepped),
        stepped[0],
        stepped[2],
        len(grown),
        grown[3]
    ];
}

def from_tuple -> list[int] {
    made = bytes((7, 8, 255));
    return [len(made), made[2]];
}

with entry {
    print(from_range(256));
    print(from_tuple());
}
