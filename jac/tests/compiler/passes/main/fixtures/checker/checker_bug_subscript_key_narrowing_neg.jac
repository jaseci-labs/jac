obj Item { has value: str = ""; }
obj Other { has code: int = 0; }

def bad_variable_index(items: list[Item | Other], i: int) -> str {
    if isinstance(items[i], Item) {
        return items[i].value;  # error: variable index not a stable key
    }
    return "";
}

def bad_range_slice(items: list[Item | Other]) -> str {
    if isinstance(items[0], Item) {
        return items[0:1][0].value;  # error: range slice not a stable key
    }
    return "";
}

def post_narrow_int_reassign(items: list[Item | Other]) -> str {
    if isinstance(items[0], Item) {
        items[0] = Other();
        x = items[0];
        return items[0].value;  # error: re-widened by subscript-target write
    }
    return "";
}

def post_narrow_neg_reassign(items: list[Item | Other]) -> str {
    if isinstance(items[-1], Item) {
        items[-1] = Other();
        return items[-1].value;  # error: re-widened by subscript-target write
    }
    return "";
}

def post_narrow_str_reassign(config: dict[str, Item | Other]) -> str {
    if isinstance(config["host"], Item) {
        config["host"] = Other();
        return config["host"].value;  # error: re-widened by subscript-target write
    }
    return "";
}
