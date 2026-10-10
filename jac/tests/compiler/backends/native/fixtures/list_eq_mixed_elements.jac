"""Lists whose elements are stored differently still compare by value."""
import struct;

def unpacked_matches(packed: &bytes, first: int, last: int) -> list[bool] {
    fields = list(struct.unpack("<3H", packed));
    wanted: list[int] = [first, 2, last];
    held = struct.unpack("<3H", packed);
    again = list(held);
    return [
        fields == wanted,
        wanted == fields,
        fields != wanted,
        again == wanted,
        fields == [first, 2, last],
        [first, 2, last] == fields,
        fields[:] == wanted,
        fields == [first, 2],
        fields == [first, 2, last, 4]
    ];
}

def loose_matches -> list[bool] {
    loose: list[any] = [1.0, 2.5, 3.0];
    exact: list[float] = [1.0, 2.5, 3.0];
    counted: list[any] = [1, 2, 3];
    whole: list[int] = [1, 2, 3];
    return [
        loose == exact,
        exact == loose,
        counted == whole,
        whole != counted,
        counted == [1, 2, 4]
    ];
}

def number_kinds_match -> list[bool] {
    whole: list[int] = [1, 2, 3];
    parts: list[float] = [1.0, 2.0, 3.0];
    other: list[float] = [1.0, 2.0, 3.5];
    return [whole == parts, parts == whole, whole == other, other != whole];
}

with entry {
    packed = struct.pack("<3H", 1, 2, 3);
    print(unpacked_matches(packed, 1, 3));
    print(unpacked_matches(packed, 1, 4));
    print(unpacked_matches(struct.pack("<3H", 65535, 2, 40000), 65535, 40000));
    print(loose_matches());
    print(number_kinds_match());
}
