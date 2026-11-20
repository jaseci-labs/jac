"""Native explicit-separator splitting preserves direction, limits and byte data."""
def:pub split_checks -> bool {
    text = "a.b.c";
    if text.rsplit(".", 1) != ["a.b", "c"] {
        return False;
    }
    if text.split(".", 1) != ["a", "b.c"] {
        return False;
    }
    if text.rsplit(".", 0) != ["a.b.c"] {
        return False;
    }
    if text.rsplit(".", -1) != ["a", "b", "c"] {
        return False;
    }
    if "aaa".rsplit("aa", 1) != ["a", ""] {
        return False;
    }
    if "aaa".split("aa", 1) != ["", "a"] {
        return False;
    }
    if "Ω😀Ω".rsplit("Ω", 1) != ["Ω😀", ""] {
        return False;
    }
    if "ab\x00c--ab\x00d".rsplit("ab\x00d", 1) != ["ab\x00c--", ""] {
        return False;
    }
    if "a".rsplit("long", 1) != ["a"] {
        return False;
    }
    if "".rsplit(".", 1) != [""] {
        return False;
    }
    try {
        text.split("");
    } except ValueError {
        return True;
    }
    return False;
}
