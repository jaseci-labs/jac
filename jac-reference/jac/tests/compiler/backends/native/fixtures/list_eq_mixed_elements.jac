"""Lists whose elements are stored differently still compare by value."""
import struct;

obj Tag {
    has name: str;
}

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

def exact_numbers_match -> list[bool] {
    # 2**53 + 1 has no double of its own: converting it to compare would round
    # it onto 2**53 and call two different numbers equal.
    whole: list[int] = [9007199254740993];
    near: list[int] = [9007199254740992];
    parts: list[float] = [9007199254740992.0];
    limit: list[int] = [9223372036854775807];
    past: list[float] = [9223372036854775808.0];
    return [
        whole == parts,
        whole != parts,
        parts == whole,
        near == parts,
        parts != near,
        limit == past,
        [0] == [-0.0],
        [0] == [0.5]
    ];
}

def unsigned_numbers_match -> list[bool] {
    top: u64 = 9223372036854775808;
    big: list[u64] = [top];
    byte: u8 = 200;
    small: list[u8] = [byte];
    loose: list[any] = [200];
    return [
        big == [9223372036854775808.0],
        [9223372036854775808.0] != big,
        small == [200.0],
        small == loose,
        loose == small
    ];
}

def loose_numbers_match -> list[bool] {
    loose: list[any] = [1, 2.0, True];
    parts: list[float] = [1.0, 2.0, 1.0];
    whole: list[int] = [1, 2, 1];
    flags: list[bool] = [True, False];
    big: list[any] = [9007199254740993];
    return [
        loose == parts,
        whole == loose,
        flags == [1, 0],
        loose[2:] == flags[:1],
        big == [9007199254740992.0],
        loose == [1, 2, "1"]
    ];
}

def byte_arrays_differ -> list[bool] {
    # A bytearray is stored as a list of bytes, but it is never equal to a list.
    raw = bytearray(b"\x01\x02");
    whole: list[int] = [1, 2];
    loose: list[any] = [1, 2];
    return [
        raw == whole,
        raw != whole,
        whole == raw,
        raw == [1, 2],
        raw == loose,
        loose != raw,
        raw == bytearray(b"\x01\x02")
    ];
}

def shared_elements_match -> list[bool] {
    # A typed list keeps rows, tables, objects and strings as bare pointers;
    # each is compared as the kind its checked type names, so the same object
    # held by a typed list and by a list of `any` is equal to itself.
    inner: list[int] = [1, 2];
    typed: list[list[int]] = [inner];
    loose: list[any] = [inner];
    table: dict[str, int] = {"a": 1};
    tables: list[dict[str, int]] = [table];
    loose_tables: list[any] = [table];
    tag = Tag(name="t");
    tags: list[Tag] = [tag];
    loose_tags: list[any] = [tag];
    other_tags: list[any] = [Tag(name="t")];
    words: list[str] = ["ab", "cd"];
    loose_words: list[any] = ["ab", "cd"];
    return [
        typed == loose,
        loose == typed,
        typed != loose,
        tables == loose_tables,
        tags == loose_tags,
        tags == other_tags,
        words == loose_words,
        words == ["ab", "ce"]
    ];
}

with entry {
    packed = struct.pack("<3H", 1, 2, 3);
    print(unpacked_matches(packed, 1, 3));
    print(unpacked_matches(packed, 1, 4));
    print(unpacked_matches(struct.pack("<3H", 65535, 2, 40000), 65535, 40000));
    print(loose_matches());
    print(number_kinds_match());
    print(exact_numbers_match());
    print(unsigned_numbers_match());
    print(loose_numbers_match());
    print(byte_arrays_differ());
    print(shared_elements_match());
}
