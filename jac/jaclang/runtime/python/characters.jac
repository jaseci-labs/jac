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

def point_char(data: bytes, pos: int) -> str {
    if data[pos] < 128 {
        return chr(data[pos]);
    }
    width = point_width(data, pos);
    return data[pos:pos + width].decode("utf-8");
}

def unicode_point(value: str) -> int {
    data = value.encode("utf-8");
    if not data {
        return -1;
    }
    lead = data[0];
    if lead < 128 {
        return lead;
    }
    width = point_width(data, 0);
    point = lead & (31 if width == 2 else 15 if width == 3 else 7);
    for index in range(1, width) {
        point = point * 64 + (data[index] & 63);
    }
    return point;
}

def unicode_start(value: str) -> bool {
    point = unicode_point(value);
    return point == 95 or (point >= 0 and _PyUnicode_IsXidStart(u32(point)) != 0);
}

def unicode_continue(value: str) -> bool {
    point = unicode_point(value);
    return point >= 0 and _PyUnicode_IsXidContinue(u32(point)) != 0;
}

def unicode_printable(value: str) -> bool {
    point = unicode_point(value);
    return point >= 0 and _PyUnicode_IsPrintable(u32(point)) != 0;
}
