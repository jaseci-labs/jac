"""Fixture for W3036: Mutable default argument in function definition."""

def bad_list(items: list = []) -> list {  # <-- Warning W3036: mutable default
    items.append(1);
    return items;
}

def bad_dict(data: dict = {}) -> dict {  # <-- Warning W3036: mutable default
    data["key"] = "val";
    return data;
}

def good(items: list | None = None) -> list {  # <-- Ok: None default
    if items is None {
        items = [];
    }
    items.append(1);
    return items;
}
