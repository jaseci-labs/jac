def:pub is_digit(c: int) -> bool {
    return c >= 48 and c <= 57;
}


def:pub is_upper(c: int) -> bool {
    return c >= 65 and c <= 90;
}


def:pub is_lower(c: int) -> bool {
    return c >= 97 and c <= 122;
}


def:pub is_alpha(c: int) -> bool {
    return is_upper(c) or is_lower(c);
}


def:pub is_word(c: int) -> bool {
    return is_digit(c) or is_upper(c) or is_lower(c) or c == 95;
}


def:pub is_id_start(c: int) -> bool {
    return is_alpha(c) or c == 95;
}


def:pub is_space(c: int) -> bool {
    return c == 32 or (c >= 9 and c <= 13);
}


def:pub swapcase(c: int) -> int {
    if is_upper(c) {
        return c + 32;
    }
    if is_lower(c) {
        return c - 32;
    }
    return c;
}


def:pub hexv(c: int) -> int {
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
