"""The bytes and bytearray constructors lower natively with CPython semantics."""

def zeroed(n: int) -> str {
    try {
        data = bytes(n);
        return f"{len(data)} {repr(data)} {data == b'\x00' * n}";
    } except ValueError as err {
        return f"bytes({n}): {err}";
    }
}

def zeroed_array(n: int) -> str {
    try {
        buf = bytearray(n);
        return f"{len(buf)} {list(buf)}";
    } except ValueError as err {
        return f"bytearray({n}): {err}";
    }
}

def from_ints(values: &list[int]) -> str {
    try {
        return repr(bytes(values));
    } except ValueError as err {
        return f"bytes(list): {err}";
    }
}

def array_from_ints(values: &list[int]) -> str {
    try {
        return str(list(bytearray(values)));
    } except ValueError as err {
        return f"bytearray(list): {err}";
    }
}

def texture(width: int, height: int) -> bytes {
    return bytes(width * height * 4);
}

def copies(src: &bytes) -> list[str] {
    frozen = bytes(src);
    buf = bytearray(src);
    buf[0] = 33;
    thawed = bytes(buf);
    grown = bytearray(buf);
    grown.append(46);
    return [
        repr(frozen),
        repr(thawed),
        repr(src),
        repr(bytes(grown)),
        repr(bytes(buf))
    ];
}

with entry {
    for n in [0, 1, 3, 8, -1, -9] {
        print(zeroed(n), "|", zeroed_array(n));
    }
    empty = bytes();
    print(len(empty), repr(empty), empty == b"", repr(bytes(0)));
    print(len(bytearray()), list(bytearray()));
    pixels = texture(3, 2);
    print(len(pixels), pixels[0], pixels[23], sum(list(pixels)));
    print(repr(bytes(True)), repr(bytes(False)), len(bytearray(True)));
    for values in [[], [104, 105], [0, 127, 128, 255], [1, 256], [-1, 2]] {
        print(from_ints(values), "|", array_from_ints(values));
    }
    print(repr(bytes([True, False, True])));
    print(copies(b"abc"), copies(b"\x00\xff"));
    print(list(bytearray(b"xy")), list(bytearray(3)), list(b"\x01\xfe"));
}
