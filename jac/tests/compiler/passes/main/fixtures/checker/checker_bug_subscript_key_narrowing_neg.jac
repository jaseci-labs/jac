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
