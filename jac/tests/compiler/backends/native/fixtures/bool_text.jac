"""Booleans from membership tests and comparisons, rendered as text."""

def membership_fstring(x: int) -> str {
    s = {1, 2};
    return f"{x in s}|{x not in s}|{x in [1, 2]}";
}

def comparison_fstring(x: int) -> str {
    return f"{x > 1}|{x == 2}|{0 < x < 3}";
}

def spec_fstring(x: int) -> str {
    s = {1, 2};
    return f"[{x in s:5}]";
}

def repr_fstring(x: int) -> str {
    s = {1, 2};
    return f"{x in s!r}";
}

def repr_text(x: int) -> str {
    s = {1, 2};
    return repr(x in s) + "|" + repr(x < 0);
}

def str_text(x: int) -> str {
    s = {1, 2};
    return str(x in s) + "|" + str(1 in [x]);
}

"""Inputs for the str predicates (eight of them): digits, letters, cased words,
blanks, empty."""
glob WORDS: list[str] = ["12", "ab", "AB", "Ab Cd", "a_1", "  ", "", "x9!"];

"""Every character-class predicate of one word, through `str()`."""
def predicate_str(x: int) -> str {
    w = WORDS[x % len(WORDS)];
    return str(w.isdigit())
        + "|"
        + str(w.isalpha())
        + "|"
        + str(w.isalnum())
        + "|"
        + str(w.isspace())
        + "|"
        + str(w.isupper())
        + "|"
        + str(w.islower())
        + "|"
        + str(w.istitle())
        + "|"
        + str(w.isdecimal())
        + "|"
        + str(w.isnumeric())
        + "|"
        + str(w.isascii())
        + "|"
        + str(w.isidentifier())
        + "|"
        + str(w.isprintable());
}

"""Prefix and suffix tests, single and tuple candidates, through an f-string."""
def affix_fstring(x: int) -> str {
    w = WORDS[x % len(WORDS)];
    head = f"{w.startswith('a')}|{w.endswith('B')}";
    return head + f"|{w.startswith(('1', 'A'))}|{w.endswith('d', 0, 5)}";
}

"""The same results under `!r`, `repr()` and inside a container's rendering."""
def predicate_repr(x: int) -> str {
    w = WORDS[x % len(WORDS)];
    return f"{w.isdigit()!r}|"
        + repr(w.isupper())
        + "|"
        + str([w.isalpha(), w.startswith("A")]);
}

"""A predicate stays a bool through a local, a comparison and arithmetic."""
def predicate_value(x: int) -> str {
    w = WORDS[x % len(WORDS)];
    d = w.isdigit();
    return f"{d}|{w.isdigit() == True}|{not w.islower()}|"
        + str(w.isalpha() + w.isdigit());
}
