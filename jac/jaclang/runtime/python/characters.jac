import from c {
    def _PyUnicode_IsXidStart(point: u32) -> i32;  def _PyUnicode_IsXidContinue(
        point: u32
    ) -> i32;  def _PyUnicode_IsPrintable(point: u32) -> i32;
}

def point_width(data: bytes, pos: int) -> int {
    lead = data[pos];
    if lead < 128 {
        return 1;
    }
    if lead < 224 {
        return 2;
    }
    if lead < 240 {
        return 3;
    }
    return 4;
}

# The code point at `pos`, decoded from its UTF-8 bytes without building a
# string. Scanners compare these against `ord("x")`, which folds to a constant.
def point_at(data: bytes, pos: int) -> int {
    lead = data[pos];
    if lead < 128 {
        return lead;
    }
    if lead < 224 {
        return ((lead & 31) << 6) | (data[pos + 1] & 63);
    }
    if lead < 240 {
        return ((lead & 15) << 12) | ((data[pos + 1] & 63) << 6) | (data[pos + 2] & 63);
    }
    return ((lead & 7) << 18)
        | ((data[pos + 1] & 63) << 12)
        | ((data[pos + 2] & 63) << 6)
        | (data[pos + 3] & 63);
}

def point_char(data: bytes, pos: int) -> str {
    if data[pos] < 128 {
        return chr(data[pos]);
    }
    width = point_width(data, pos);
    return data[pos:pos + width].decode("utf-8");
}

def unicode_point(value: str) -> int {
    return ord(value) if value else -1;
}

def unicode_start(point: int) -> bool {
    return point == 95 or (point >= 0 and _PyUnicode_IsXidStart(u32(point)) != 0);
}

def unicode_continue(point: int) -> bool {
    return point >= 0 and _PyUnicode_IsXidContinue(u32(point)) != 0;
}

def unicode_printable(point: int) -> bool {
    return point >= 0 and _PyUnicode_IsPrintable(u32(point)) != 0;
}
