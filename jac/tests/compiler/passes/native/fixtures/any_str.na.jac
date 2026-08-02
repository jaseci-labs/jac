"""Native str() on an `any`-boxed scalar (#7498): calling str() on a value
boxed as `any` (e.g. the return of dict.get on a dict[str, any]) must unbox the
JacVal and stringify the underlying scalar, not the type-discriminant tag.
"""

def any_str_str -> str {
    d: dict[str, any] = {"s": "hello"};
    return str(d.get("s", ""));
}

def any_str_int -> str {
    d: dict[str, any] = {"n": 7};
    return str(d.get("n", 0));
}

def any_str_float -> str {
    d: dict[str, any] = {"f": 1.5};
    return str(d.get("f", 0.0));
}

def any_str_bool -> str {
    d: dict[str, any] = {"b": True};
    return str(d.get("b", False));
}

def any_str_none -> str {
    d: dict[str, any] = {"z": None};
    return str(d.get("z", 0));
}
