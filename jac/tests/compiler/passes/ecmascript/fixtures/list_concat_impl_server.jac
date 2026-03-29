"""Server module for list_concat_impl test."""

obj Item {
    has name: str;
}

def:pub add_item(name: str) -> dict {
    return {"name": name};
}
