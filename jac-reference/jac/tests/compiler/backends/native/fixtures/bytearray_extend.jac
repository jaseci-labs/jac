"""Checked native bytearray extension from integer lists and raw buffers."""
obj Source {
    has calls: int = 0;

    def values -> list[int] {
        self.calls += 1;
        return [0, 128, 255];
    }
}

def extend_values(value: int) -> int {
    data = bytearray(b"A");
    values: list[int] = [0, value, 255];
    data.extend(values);
    assert values == [0, value, 255];
    assert len(data) == 4 and data[0] == 65 and data[1] == 0 and data[3] == 255;
    return int(data[2]);
}

def typed_and_inline -> bool {
    data = bytearray();
    values: list[u8] = [u8(0), u8(128), u8(255)];
    data.extend(values);
    data.extend([u8(1), u8(0), u8(2)]);
    data.extend([0, 127, 255]);
    empty: list[int] = [];
    data.extend(empty);
    return bytes(data) == b"\x00\x80\xff\x01\x00\x02\x00\x7f\xff";
}

def invalid_values(value: int) -> bool {
    data = bytearray(b"original");
    try {
        data.extend([1, 2, value, 3]);
    } except ValueError {
        # Failed concrete-list extension must leave the destination intact.
        return bytes(data) == b"original";
    }
    return False;
}

def source_once -> bool {
    source = Source();
    data = bytearray();
    data.extend(source.values());
    return source.calls == 1 and bytes(data) == b"\x00\x80\xff";
}

def buffers_and_aliases -> bool {
    data = bytearray(b"ab");
    data.extend(b"\x00\xff");
    source = bytearray(b"cd");
    data.extend(source);
    alias = data;
    data.extend(alias);
    data.extend(data);
    data.extend(b"");
    return bytes(data) == b"ab\x00\xffcd" * 4 and bytes(source) == b"cd";
}

with entry {
    assert extend_values(255) == 255;
    assert typed_and_inline();
    assert invalid_values(-1) and invalid_values(256);
    assert source_once() and buffers_and_aliases();
    print("bytearray extend OK");
}
