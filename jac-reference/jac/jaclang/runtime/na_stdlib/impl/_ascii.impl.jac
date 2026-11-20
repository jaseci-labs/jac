impl is_digit(c: int) -> bool {
    return c >= 48 and c <= 57;
}


impl is_upper(c: int) -> bool {
    return c >= 65 and c <= 90;
}


impl is_lower(c: int) -> bool {
    return c >= 97 and c <= 122;
}


impl is_alpha(c: int) -> bool {
    return is_upper(c) or is_lower(c);
}


impl is_word(c: int) -> bool {
    return is_digit(c) or is_upper(c) or is_lower(c) or c == 95;
}


impl is_id_start(c: int) -> bool {
    return is_alpha(c) or c == 95;
}


impl is_space(c: int) -> bool {
    return c == 32 or (c >= 9 and c <= 13);
}


impl swapcase(c: int) -> int {
    if is_upper(c) {
        return c + 32;
    }
    if is_lower(c) {
        return c - 32;
    }
    return c;
}


impl hexv(c: int) -> int {
    if is_digit(c) {
        return c - 48;
    }
    if c >= 65 and c <= 70 {
        return c - 55;
    }
    if c >= 97 and c <= 102 {
        return c - 87;
    }
    return -1;
}
