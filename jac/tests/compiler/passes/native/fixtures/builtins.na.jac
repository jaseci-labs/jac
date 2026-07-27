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

# Leak regression (#6814): split() must not strand its fresh token strings.
# Parameterized so the test can drive a large (200-element) input to amplify
# any per-token leak; the returned list is a scope-local freed at exit.
def split_count(s: str, sep: str) -> int {
    parts: list[str] = s.split(sep);
    return len(parts);
}

# Leak regression (#6814): str[i:j] substring slicing must not strand the
# freshly-allocated result. Returns the half-length of a scope-local slice.
def slice_half_len(s: str) -> int {
    half: str = s[0:len(s) / 2];
    return len(half);
}
