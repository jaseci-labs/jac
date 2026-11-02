def hex_lower -> int {
    return int("1b", 16);
}

def hex_upper -> int {
    return int("FF", 16);
}

def hex_prefixed -> int {
    return int("0x10", 16);
}

def octal -> int {
    return int("033", 8);
}

def binary -> int {
    return int("101", 2);
}

def sliced_hex -> int {
    text = "\\x1b[31m";
    return int(text[2:4], 16);
}

def decimal_default -> int {
    return int("42");
}
