"""Fixture: len() must dispatch on the argument's type (#7883 / #7922).

`.length` is undefined on plain JS objects (dict) and Set, so len() must
emit Object.keys(x).length for dicts, .size for sets, and fall back to a
runtime helper when the static type is unknown.
"""

def t_len_dict -> int {
    d: dict[str, int] = {"a": 1, "b": 2};
    return len(d);
}

def t_len_set -> int {
    s: set[int] = {1, 2, 3};
    return len(s);
}

def opaque(x: any) -> any {
    return x;
}

def t_len_any -> int {
    return len(opaque([1, 2, 3, 4]));
}

def t_len_list -> int {
    return len([1, 2, 3]);
}

def t_len_str -> int {
    return len("abcd");
}

def t_len_all -> dict {
    return {
        "d": t_len_dict(),
        "s": t_len_set(),
        "a": t_len_any(),
        "l": t_len_list(),
        "st": t_len_str()
    };
}
