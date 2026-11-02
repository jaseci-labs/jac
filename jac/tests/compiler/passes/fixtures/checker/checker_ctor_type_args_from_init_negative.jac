"""The typed result of `dict(...)` is checked like any other typed dict.

Each function misuses what it built; while `dict(...)` was a bare `dict`
none of these was seen.
"""

def copied(fields: dict[str, str]) -> int {
    copy = dict(fields);
    return copy.get("angle", "0");
}

def paired(pairs: list[tuple[str, int]]) -> str {
    table = dict(pairs);
    return table["a"];
}

def by_keywords -> dict[str, str] {
    made = dict(a=1, b=2);
    return made;
}

def from_literal -> dict[str, str] {
    made = dict({1: "one"});
    return made;
}
