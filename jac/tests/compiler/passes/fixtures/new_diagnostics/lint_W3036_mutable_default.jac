"""Fixture for W3036: Mutable default argument in function definition."""

def bad_list(items: list[any] = []) -> list[any] {  # <-- Warning W3036: mutable default
    items.append(1);
    return items;
}

def bad_dict(data: dict[any, any] = {}) -> dict[any, any] {  # <-- Warning W3036: mutable default
    data["key"] = "val";
    return data;
}

def good(items: list[any] | None = None) -> list[any] {  # <-- Ok: None default
    if items is None {
        items = [];
    }
    items.append(1);
    return items;
}
