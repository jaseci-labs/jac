"""Native dictionary displays preserve spread order and owned values."""
glob drops: int = 0;
obj Item {
    has value: int;

    def drop {
        drops += 1;
    }
}

def make_items -> dict[str, Item] {
    return {"x": Item(value=42)};
}

def object_copy -> int {
    values = {** make_items()};
    return values["x"].value;
}

def:pub dict_unpack_check -> int {
    source = {"a": 1, "b": 2};
    result = {"first": 0, ** source, "a": 3, ** {"last": 4}};
    if list(result.keys()) != ["first", "a", "b", "last"] {
        return 1;
    }
    if result["a"] != 3 or result["b"] != 2 or result["last"] != 4 {
        return 2;
    }
    if source["a"] != 1 {
        return 3;
    }
    empty: dict[str, int] = {};
    copied = {** empty, ** source};
    if len(copied) != 2 or copied["a"] != 1 or copied["b"] != 2 {
        return 4;
    }
    before = drops;
    if object_copy() != 42 {
        return 5;
    }
    if drops != before + 1 {
        return 6;
    }
    return 0;
}
