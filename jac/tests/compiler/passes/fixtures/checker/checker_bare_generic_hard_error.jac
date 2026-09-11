"""A generic written without type arguments is a hard error at every
annotation site, and its value type recovers as Unknown."""

def bare_dict_ret -> dict {
    return {"a": 1};
}

def bare_list_param(items: list) -> None {
    print(items);
}

with entry {
    d: dict = {"a": 1};
    l: list = [1];
    t: tuple = (1, );
}

# Nested bare generics are reported too: the outer type is parameterised but
# the inner one still leaves its value type unnamed.
def nested_list_of_dict -> list[dict] {
    return [{"a": 1}];
}

def nested_dict_of_list(rows: dict[str, list]) -> None {
    print(rows);
}

with entry {
    deep: dict[str, list[tuple]] = {};
}
