import json;

def as_int(value: any) -> int {
    return int(value);
}

def from_field(raw: dict[str, any], key: str) -> int {
    return int(raw.get(key, 0));
}

def:pub int_of_boxed_int -> int {
    return as_int(41) + 1;
}

def:pub int_of_boxed_bool -> int {
    return as_int(True) * 10 + as_int(False);
}

def:pub int_of_boxed_float -> int {
    return as_int(-7.9) * 100 + as_int(3.99);
}

def:pub int_of_boxed_str -> int {
    return as_int("123") + as_int("-4");
}

def:pub int_of_json_fields -> int {
    raw: dict[str, any] = json.loads('{"a": 5, "b": 2.5, "c": true, "d": "17"}');
    return from_field(raw, "a") * 1000
        + from_field(raw, "b") * 100
        + from_field(raw, "c") * 10
        + from_field(raw, "d") % 10
        + from_field(raw, "missing");
}

def:pub int_of_boxed_bad_str -> int {
    try {
        return as_int("12x");
    } except ValueError {
        return -1;
    }
}

def:pub int_of_boxed_list -> int {
    try {
        return as_int([1, 2]);
    } except TypeError {
        return -2;
    }
}
