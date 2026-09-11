"""Explicitly parameterised generics propagate `any` through chained
subscripts, attribute access and iteration into typed targets."""

obj Holder {
    has label: str;
}

def nested_dict -> dict[str, any] {
    return {"sys": {"country": "LK"}, "count": {"n": 1}};
}

def nested_list -> list[any] {
    return [["a"]];
}

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

def explicit_dict_into_param -> Holder {
    d: dict[str, any] = nested_dict();
    return Holder(label=d["sys"]["country"]);
}
