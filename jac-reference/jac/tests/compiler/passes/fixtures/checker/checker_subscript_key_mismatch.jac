def take_str(sym: str) -> str {
    return sym;
}

def wrong_key(k: str) -> str {
    table: dict[int, str] = {1: "a", 2: "b"};
    return take_str(table[k]);
}

def right_key(k: int) -> str {
    table: dict[int, str] = {1: "a", 2: "b"};
    return take_str(table[k]);
}

def key_checked_by_in(k: (int | str)) -> str {
    table: dict[int, str] = {1: "a", 2: "b"};
    return take_str(table[k]) if k in table else "";
}

obj Holder {
    has table: dict[int, str] = {};
}

def key_checked_after_none(h: (Holder | None), k: (int | str)) -> str {
    return take_str(h.table[k]) if h is not None and k in h.table else "";
}

def union_key(k: (int | str | None), table: dict[(int | str), str]) -> str {
    return take_str(table[k]) if k in table else "";
}

def float_key(k: float, table: dict[int, str]) {
    if k in table {
        print(k.bit_length());
    }
}
