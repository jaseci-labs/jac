impl _range_value(index: int) -> int {
    offset = index * 4;
    return int(UNICODE_PROPERTY_RANGES[offset])
        | (int(UNICODE_PROPERTY_RANGES[offset + 1]) << 8)
        | (int(UNICODE_PROPERTY_RANGES[offset + 2]) << 16)
        | (int(UNICODE_PROPERTY_RANGES[offset + 3]) << 24);
}

impl category(chr: str) -> str {
    if len(chr) != 1 {
        raise TypeError("category() argument must be a unicode character, not str");
    }
    code = ord(chr);
    low = 0;
    high = len(UNICODE_PROPERTY_RANGES) // 16;
    while low < high {
        middle = (low + high) // 2;
        start = _range_value(middle * 4);
        end = _range_value(middle * 4 + 1);
        if code < start {
            high = middle;
        } elif code > end {
            low = middle + 1;
        } else {
            return UNICODE_CATEGORIES[_range_value(middle * 4 + 2)];
        }
    }
    return "Cn";
}

impl east_asian_width(chr: str) -> str {
    if len(chr) != 1 {
        raise TypeError(
            "east_asian_width() argument must be a unicode character, not str"
        );
    }
    code = ord(chr);
    low = 0;
    high = len(UNICODE_PROPERTY_RANGES) // 16;
    while low < high {
        middle = (low + high) // 2;
        start = _range_value(middle * 4);
        end = _range_value(middle * 4 + 1);
        if code < start {
            high = middle;
        } elif code > end {
            low = middle + 1;
        } else {
            return UNICODE_EAST_ASIAN_WIDTHS[_range_value(middle * 4 + 3)];
        }
    }
    return "N";
}
