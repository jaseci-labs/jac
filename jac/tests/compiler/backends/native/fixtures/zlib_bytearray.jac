import zlib;

def bytearray_checks -> bool {
    expected = b"\x00\xff\x80binary\r\n" * 500;
    compressed = zlib.compress(expected);
    mutable = bytearray(compressed);
    decoded = zlib.decompress(mutable);
    assert decoded == expected;
    assert zlib.decompress(compressed) == expected;
    assert bytes(mutable) == compressed;
    assert zlib.decompress(bytearray(zlib.compress(b""))) == b"";
    try {
        zlib.decompress(bytearray(b"invalid stream"));
    } except ValueError {
        return True;
    }
    return False;
}

def buffer_kind(value: bytes | bytearray) -> int {
    if not isinstance(value, (bytes, bytearray)) {
        return 0;
    }
    if isinstance(value, bytearray) {
        return 1;
    }
    if isinstance(value, bytes) {
        return 2;
    }
    return 3;
}

def buffer_union_checks -> bool {
    return buffer_kind(b"\x00\xff") == 2
        and buffer_kind(bytearray(b"\x00\xff")) == 1
        and buffer_kind(b"") == 2
        and buffer_kind(bytearray()) == 1;
}

def any_buffer(value: any) -> bool {
    return isinstance(value, (bytes, bytearray));
}

def any_buffer_checks -> bool {
    return any_buffer(b"x")
        and any_buffer(bytearray(b"x"))
        and not any_buffer(42)
        and not any_buffer(True)
        and not any_buffer(1.5)
        and not any_buffer(None)
        and not any_buffer("x")
        and not any_buffer([1, 2]);
}

def buffer_case(index: int) -> int {
    if index == 0 {
        return buffer_kind(b"\x00\xff");
    }
    if index == 1 {
        return buffer_kind(bytearray(b"\x00\xff"));
    }
    if index == 2 {
        return buffer_kind(b"");
    }
    return buffer_kind(bytearray());
}
