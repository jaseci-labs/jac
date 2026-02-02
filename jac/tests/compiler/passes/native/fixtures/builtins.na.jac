# String character access: s[i] returns single-char string
def test_char_at() -> int {
    s: str = "hello";
    c: str = s[1];
    return ord(c);
}

# ord() returns integer code of first character
def test_ord() -> int {
    return ord("a");
}

# int() parses string to integer
def test_int_parse() -> int {
    return int("42");
}

# strip() trims leading/trailing whitespace
def test_strip() -> str {
    s: str = "  hi  ";
    return s.strip();
}

# split() splits string by separator, returns list[str]
def test_split_len() -> int {
    s: str = "a b c";
    parts: list[str] = s.split(" ");
    return len(parts);
}

# split() + indexing
def test_split_get() -> str {
    s: str = "hello world";
    parts: list[str] = s.split(" ");
    return parts[1];
}

# Combined: strip + split
def test_strip_split() -> int {
    s: str = "  e2 e4  ";
    t: str = s.strip();
    parts: list[str] = t.split(" ");
    return len(parts);
}
