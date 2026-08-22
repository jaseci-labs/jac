# P3.2e — byte character-class helpers.
# Lift: Objects/_lifted/bytes_methods_core.jac

def bytes_isupper_byte(c: int) -> bool {
    return c >= 65 and c <= 90;
}

def bytes_islower_byte(c: int) -> bool {
    return c >= 97 and c <= 122;
}

def bytes_isdigit_byte(c: int) -> bool {
    return c >= 48 and c <= 57;
}

def bytes_isspace_byte(c: int) -> bool {
    return c == 32 or c == 9 or c == 10 or c == 13 or c == 12 or c == 11;
}

def bytes_toupper_byte(c: int) -> int {
    if bytes_islower_byte(c) {
        return c - 32;
    }
    return c;
}

def bytes_tolower_byte(c: int) -> int {
    if bytes_isupper_byte(c) {
        return c + 32;
    }
    return c;
}
