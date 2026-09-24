"""Bytes search methods lower natively with CPython semantics."""

def name_of(raw: &bytes) -> str {
    end = raw.find(b"\x00");
    return (raw[:end] if end >= 0 else raw).decode("utf-8");
}

def finds(data: &bytes, needle: &bytes, start: int, end: int) -> list[int] {
    return [
        data.find(needle),
        data.find(needle, start),
        data.find(needle, start, end),
        data.rfind(needle),
        data.rfind(needle, start),
        data.rfind(needle, start, end),
        data.count(needle),
        data.count(needle, start),
        data.count(needle, start, end)
    ];
}

def byte_finds(data: &bytes, byte: int, start: int, end: int) -> list[int] {
    return [
        data.find(byte),
        data.find(byte, start, end),
        data.rfind(byte),
        data.rfind(byte, start, end),
        data.count(byte),
        data.count(byte, start, end)
    ];
}

def affixes(data: &bytes, affix: &bytes, start: int, end: int) -> list[bool] {
    return [
        data.startswith(affix),
        data.startswith(affix, start),
        data.startswith(affix, start, end),
        data.endswith(affix),
        data.endswith(affix, start),
        data.endswith(affix, start, end),
        data.startswith((b"zz", affix)),
        data.endswith((affix, b"zz"), start, end)
    ];
}

def index_of(data: &bytes, needle: &bytes, start: int, end: int) -> int {
    try {
        return data.index(needle, start, end);
    } except ValueError as err {
        print("index:", err);
    }
    return -100;
}

def rindex_of(data: &bytes, needle: &bytes, start: int) -> int {
    try {
        return data.rindex(needle, start);
    } except ValueError as err {
        print("rindex:", err);
    }
    return -100;
}

def byte_index(data: &bytes, byte: int) -> int {
    try {
        return data.index(byte);
    } except ValueError as err {
        print("byte index:", err);
    }
    return -100;
}

def contains(data: &bytes, needle: &bytes, byte: int) -> list[bool] {
    return [needle in data, needle not in data, byte in data, byte not in data];
}

def out_of_range(data: &bytes, byte: int) -> str {
    try {
        return str(data.find(byte));
    } except ValueError as err {
        return f"find: {err}";
    }
}

def out_of_range_in(data: &bytes, byte: int) -> str {
    try {
        return str(byte in data);
    } except ValueError as err {
        return f"in: {err}";
    }
}

def sweep {
    haystacks = [b"", b"abc", b"abcabc", b"a\x00b\x00a\x00b", b"aaaa", b"\xff\x00\xff"];
    needles = [
        b"",
        b"a",
        b"b\x00",
        b"abc",
        b"aa",
        b"\xff",
        b"zz",
        b"a\x00b\x00a\x00b!"
    ];
    bounds = [-9, -2, 0, 1, 3, 4, 9];
    for data in haystacks {
        for needle in needles {
            for start in bounds {
                for end in bounds {
                    print(
                        finds(data, needle, start, end),
                        affixes(data, needle, start, end)
                    );
                }
            }
            print(
                index_of(data, needle, 0, 6),
                rindex_of(data, needle, 1),
                contains(data, needle, 0)
            );
        }
        for byte in [0, 97, 98, 255] {
            for start in bounds {
                print(byte_finds(data, byte, start, -1), contains(data, b"", byte));
            }
            print(byte_index(data, byte));
        }
    }
}

with entry {
    print(name_of(b"sbar\x00\x00junk"), name_of(b"nonul"), name_of(b"\x00lead"));
    sweep();
    print(
        b"abcabc".find(b"c"),
        b"abc".find(b"z"),
        b"abcabc".rfind(b"b"),
        b"a,b".index(b",")
    );
    print(
        b"abcabc".count(b"bc"),
        b"aaaa".count(b"aa"),
        b"abc".rindex(b"c"),
        b"abc".count(99)
    );
    print(b"abc".startswith(b"ab"), b"abc".endswith((b"x", b"bc")), 98 in b"abc");
    # str shares the affix kernel; its result is a real bool, not 1/0.
    print("abc".startswith("ab"), "abc".endswith(("x", "bc")), "abc".startswith("b"));
    for byte in [-1, 256, 1000] {
        print(out_of_range(b"abc", byte), out_of_range_in(b"abc", byte));
    }
}
