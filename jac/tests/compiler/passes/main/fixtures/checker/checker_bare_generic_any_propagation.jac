"""A bare generic's value type is any, so operations on it yield any again and
flow into typed targets exactly like an explicitly written dict[str, any] does."""

obj Holder {
    has label: str;
}

def nested_dict -> dict {
    return {"sys": {"country": "LK"}, "count": {"n": 1}};
}

def nested_list -> list {
    return [["a"]];
}

def nested_tuple -> tuple {
    return (("a", ), );
}

# Chained subscript on a bare generic, into typed targets.
def bare_dict_chained -> str {
    d: dict = nested_dict();
    return d["sys"]["country"];
}

def bare_list_chained -> str {
    l: list = nested_list();
    return l[0][0];
}

def bare_tuple_chained -> str {
    t: tuple = nested_tuple();
    return t[0][0];
}

# Attribute access on a bare generic's value type.
def bare_dict_attr -> str {
    d: dict = {"a": "x"};
    return d["a"].upper();
}

# Iterating a bare generic's value type.
def bare_dict_iter -> str {
    d: dict = {"items": ["x"]};
    for item in d["items"] {
        return item;
    }
    return "";
}

# Passing a nested lookup into a typed parameter.
def bare_dict_into_param -> Holder {
    d: dict = nested_dict();
    return Holder(label=d["sys"]["country"]);
}

# The explicit spelling must keep behaving identically.
def explicit_dict_chained -> str {
    d: dict[str, any] = nested_dict();
    return d["sys"]["country"];
}

def explicit_dict_attr -> str {
    d: dict[str, any] = {"a": "x"};
    return d["a"].upper();
}

def explicit_list_chained -> str {
    l: list[any] = nested_list();
    return l[0][0];
}

def explicit_dict_iter -> str {
    d: dict[str, any] = {"items": ["x"]};
    for item in d["items"] {
        return item;
    }
    return "";
}
