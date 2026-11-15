"""bytes.join over a list of bytes lowers natively with CPython semantics."""

def glue(separator: &bytes, parts: &list[bytes]) -> bytes {
    return separator.join(parts);
}

def palette(count: int) -> list[bytes] {
    return [bytes([index, index + 1, 255]) for index in range(count)];
}

def spaced(words: &list[str]) -> str {
    return " ".join(words);
}

def show(data: &bytes) -> str {
    return ",".join([str(value) for value in data]);
}

with entry {
    print(glue(b"-", [b"ab", b"cd", b"e"]).decode("utf-8"));
    print(len(glue(b"-", [])), len(glue(b"::", [b"x"])));
    print(show(glue(b"", palette(3))));
    print(show(b"\x00".join([b"a\x00b", b"", b"c"])));
    print(glue(b", ", [b"one", b"two"]).decode("utf-8"), len(glue(b"", [b""])));
    print(spaced(["kept", "as", "str"]));
}
