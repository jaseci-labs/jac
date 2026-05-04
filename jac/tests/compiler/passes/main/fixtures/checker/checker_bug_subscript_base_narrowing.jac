obj StringVal {
    has lit_value: str = "";
}

obj TokenVal {
    has name: str = "";
}

obj NumberVal {
    has num: int = 0;
}

def get_lit(path: list[StringVal | TokenVal]) -> str {
    if len(path) == 1 and isinstance(path[0], StringVal) {
        return path[0].lit_value;  # ok: path[0] narrowed to StringVal
    }
    return "";
}

def describe_first(items: list[StringVal | TokenVal | NumberVal]) -> str {
    if isinstance(items[0], StringVal) {
        return items[0].lit_value;  # ok: items[0] narrowed to StringVal
    } elif isinstance(items[0], NumberVal) {
        return str(items[0].num);   # ok: items[0] narrowed to NumberVal
    }
    return items[0].name;           # ok: items[0] narrowed to TokenVal (only remaining)
}
