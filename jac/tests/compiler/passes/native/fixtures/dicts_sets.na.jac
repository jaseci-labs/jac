# ===================== Dictionary Tests =====================

def dict_new_empty() -> int {
    d: dict[int, int] = {};
    return len(d);
}

def dict_literal_len() -> int {
    d: dict[int, int] = {1: 10, 2: 20, 3: 30};
    return len(d);
}

def dict_get_value() -> int {
    d: dict[int, int] = {1: 100, 2: 200, 3: 300};
    return d[2];
}

def dict_set_value() -> int {
    d: dict[int, int] = {1: 10};
    d[2] = 20;
    return d[2];
}

def dict_update_value() -> int {
    d: dict[int, int] = {1: 10, 2: 20};
    d[1] = 99;
    return d[1];
}

def dict_len_after_set() -> int {
    d: dict[int, int] = {1: 10};
    d[2] = 20;
    d[3] = 30;
    return len(d);
}

def dict_contains_true() -> int {
    d: dict[int, int] = {1: 10, 2: 20, 3: 30};
    if 2 in d {
        return 1;
    }
    return 0;
}

def dict_contains_false() -> int {
    d: dict[int, int] = {1: 10, 2: 20, 3: 30};
    if 99 in d {
        return 1;
    }
    return 0;
}

def dict_string_keys() -> int {
    d: dict[str, int] = {"a": 1, "b": 2, "c": 3};
    return d["b"];
}

def dict_string_values() -> str {
    d: dict[int, str] = {1: "one", 2: "two", 3: "three"};
    return d[2];
}

def dict_sum_values() -> int {
    d: dict[int, int] = {1: 10, 2: 20, 3: 30, 4: 40};
    total: int = 0;
    total = total + d[1];
    total = total + d[2];
    total = total + d[3];
    total = total + d[4];
    return total;
}

def dict_overwrite() -> int {
    d: dict[int, int] = {};
    d[1] = 10;
    d[1] = 20;
    d[1] = 30;
    return d[1];
}

def dict_multiple_types() -> int {
    d1: dict[int, int] = {1: 100};
    d2: dict[str, int] = {"key": 200};
    return d1[1] + d2["key"];
}

def dict_get_first() -> int {
    d: dict[int, int] = {1: 100, 2: 200};
    return d[1];
}

def dict_get_third() -> int {
    d: dict[int, int] = {1: 100, 2: 200, 3: 300};
    return d[3];
}

def dict_set_then_get() -> int {
    d: dict[int, int] = {};
    d[5] = 500;
    d[10] = 1000;
    return d[5] + d[10];
}

# ===================== Set Tests =====================

def set_new_empty() -> int {
    s: set[int] = set();
    return len(s);
}

def set_literal_len() -> int {
    s: set[int] = {1, 2, 3, 4, 5};
    return len(s);
}

def set_add_element() -> int {
    s: set[int] = {1, 2, 3};
    s.add(4);
    return len(s);
}

def set_add_duplicate() -> int {
    s: set[int] = {1, 2, 3};
    s.add(2);
    return len(s);
}

def set_contains_true() -> int {
    s: set[int] = {10, 20, 30};
    if 20 in s {
        return 1;
    }
    return 0;
}

def set_contains_false() -> int {
    s: set[int] = {10, 20, 30};
    if 99 in s {
        return 1;
    }
    return 0;
}

def set_string_elements() -> int {
    s: set[str] = {"apple", "banana", "cherry"};
    if "banana" in s {
        return 1;
    }
    return 0;
}

def set_multiple_adds() -> int {
    s: set[int] = set();
    s.add(1);
    s.add(2);
    s.add(3);
    s.add(2);
    s.add(1);
    return len(s);
}

# ===================== Global Dict Tests =====================

glob LOOKUP: dict[int, int] = {0: 100, 1: 200, 2: 300};

def global_dict_get() -> int {
    return LOOKUP[1];
}

def global_dict_len() -> int {
    return len(LOOKUP);
}

# ===================== Global Set Tests =====================

glob VALID_IDS: set[int] = {1, 2, 3, 4, 5};

def global_set_contains() -> int {
    if 3 in VALID_IDS {
        return 1;
    }
    return 0;
}

def global_set_len() -> int {
    return len(VALID_IDS);
}

# ===================== Entry Point =====================
glob _init_done: int = 0;

with entry {
    _init_done = 1;
}
