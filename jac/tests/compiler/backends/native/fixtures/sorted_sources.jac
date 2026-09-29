"""sorted() and list() over every native iterable, rendered as text."""

def digits(xs: list[int]) -> str {
    out = "";
    for v in xs {
        out += str(v) + ",";
    }
    return out;
}

def sorted_set(x: int) -> str {
    return digits(sorted({3, x, 1}));
}

def sorted_tuple(x: int) -> str {
    return digits(sorted((5, x, 6)));
}

def sorted_bytes(x: int) -> str {
    return digits(sorted(b"\x03\x01"));
}

def sorted_reverse(x: int) -> str {
    return digits(sorted({9, x, 8}, reverse=True));
}

def sorted_dict_keys(x: int) -> str {
    keys = sorted({"b": 1, "a": x});
    return keys[0] + keys[1];
}

def sorted_str(x: int) -> str {
    letters = sorted("cab");
    return letters[0] + letters[1] + letters[2];
}

def list_of_range(x: int) -> str {
    r = range(x, 0, -2);
    return digits(list(r));
}

def list_of_dict(x: int) -> str {
    keys = list({"k": 1, "j": x});
    return keys[0] + keys[1];
}
