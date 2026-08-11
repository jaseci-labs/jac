"""Fixture: dict.get miss/None semantics on the client (#7884 / #7922).

A miss must produce a real Jac None (JS null), a stored None must be
returned as stored (never replaced by the default), and a provided
default must only apply on a genuine miss.
"""

def get_is_none -> bool {
    d: dict[str, int] = {"value": 1};
    return d.get("error") is None;
}

def get_is_not_none -> bool {
    d: dict[str, int] = {"value": 1};
    return d.get("error") is not None;
}

def get_present -> int {
    d: dict[str, int] = {"value": 1};
    return d.get("value");
}

def get_stored_none_no_default -> bool {
    d: dict[str, any] = {"k": None};
    return d.get("k") is None;
}

def get_stored_none_with_default -> bool {
    d: dict[str, any] = {"k": None};
    return d.get("k", 5) is None;
}

def get_miss_with_default -> int {
    d: dict[str, int] = {"value": 1};
    return d.get("missing", 7);
}

def get_all -> dict {
    return {
        "miss_is_none": get_is_none(),
        "miss_is_not_none": get_is_not_none(),
        "present": get_present(),
        "stored_none": get_stored_none_no_default(),
        "stored_none_default": get_stored_none_with_default(),
        "miss_default": get_miss_with_default()
    };
}
