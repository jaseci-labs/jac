"""Dict method primitives: get, keys, values, items, update, copy."""

def dict_methods_py() -> dict {
    d: dict = {"a": 1, "b": 2, "c": 3};

    # get with existing key
    get_hit: int = d.get("a", 0);
    # get with missing key + default
    get_miss: int = d.get("z", -1);

    # keys
    keys: list = list(d.keys());

    # values
    values: list = list(d.values());

    # items
    items: list = list(d.items());

    # update (mutates in-place)
    d2: dict = {"x": 10};
    d2.update({"y": 20, "z": 30});

    # copy
    d3: dict = d.copy();

    return {
        "get_hit": get_hit,
        "get_miss": get_miss,
        "keys": keys,
        "values": values,
        "items": items,
        "after_update": d2,
        "copy": d3
    };
}

cl def dict_methods_cl() -> dict {
    d: dict = {"a": 1, "b": 2, "c": 3};

    # get with existing key
    get_hit: int = d.get("a", 0);
    # get with missing key + default
    get_miss: int = d.get("z", -1);

    # keys
    keys: list = list(d.keys());

    # values
    values: list = list(d.values());

    # items
    items: list = list(d.items());

    # update (mutates in-place)
    d2: dict = {"x": 10};
    d2.update({"y": 20, "z": 30});

    # copy
    d3: dict = d.copy();

    return {
        "get_hit": get_hit,
        "get_miss": get_miss,
        "keys": keys,
        "values": values,
        "items": items,
        "after_update": d2,
        "copy": d3
    };
}
