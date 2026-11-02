impl stderr_write(text: str) -> int {
    data = text.encode("utf-8");
    write(i32(2), data, len(data));
    return len(text);
}

impl stdout_write(text: str) -> int {
    data = text.encode("utf-8");
    write(i32(1), data, len(data));
    return len(text);
}

impl stderr_flush {}

impl stdout_flush {}

impl set_int_max_str_digits(maxdigits: int) {
    _INT_MAX_STR_DIGITS[0] = maxdigits;
}

impl get_int_max_str_digits -> int {
    return _INT_MAX_STR_DIGITS[0];
}
