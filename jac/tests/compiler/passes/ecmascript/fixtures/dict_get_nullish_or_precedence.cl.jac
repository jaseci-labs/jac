"""Fixture: ?? lowering combined with or/and must emit valid JS.

`getattr(obj, key, default)` lowers to `(obj[key] ?? default)` and one-arg
`dict.get(key)` lowers to `(obj[key] ?? undefined)`. When those results flow
into Jac `or` / `and`, the parenthesized ?? subexpression must stay grouped
— unparenthesized ?? mixed with ||/&& is a SyntaxError.
"""

cl def getattr_two_arg_or_empty(o: object) -> str {
    return getattr(o, "k", "") or "";
}

cl def getattr_numeric_or_zero(o: object) -> int {
    return getattr(o, "n", 0) or 0;
}

cl def getattr_or_fallback(o: object) -> str {
    return getattr(o, "k", "") or "fallback";
}

cl def getattr_or_empty_dict(o: object) -> dict {
    return getattr(o, "paths", None) or {};
}

cl def getattr_chain_or(o: object) -> str {
    return getattr(o, "a", "") or getattr(o, "b", "") or "c";
}

cl def literal_or_getattr(o: object) -> str {
    return "x" or getattr(o, "k", "");
}

cl def getattr_and_true(o: object) -> bool {
    return getattr(o, "flag", 0) and True;
}

cl def getattr_alone(o: object) -> str {
    return getattr(o, "k", "default");
}

cl def dict_get_or_empty(d: dict) -> str {
    return d.get("k", "") or "";
}

cl def dict_get_one_arg_or_empty(d: dict) -> str {
    return d.get("k") or "";
}

cl def test_nullish_logical_precedence_cases() -> dict {
    return {
        "getattr_two_arg_hit": getattr_two_arg_or_empty({"k": "hi"}),
        "getattr_two_arg_miss": getattr_two_arg_or_empty({}),
        "getattr_two_arg_falsy": getattr_two_arg_or_empty({"k": ""}),
        "getattr_numeric_hit": getattr_numeric_or_zero({"n": 5}),
        "getattr_numeric_miss": getattr_numeric_or_zero({}),
        "getattr_numeric_falsy": getattr_numeric_or_zero({"n": 0}),
        "getattr_fallback_hit": getattr_or_fallback({"k": "hi"}),
        "getattr_fallback_miss": getattr_or_fallback({}),
        "getattr_dict_or_hit": getattr_or_empty_dict({"paths": {"a": 1}}),
        "getattr_dict_or_miss": getattr_or_empty_dict({}),
        "getattr_chain_first": getattr_chain_or({"a": "A"}),
        "getattr_chain_second": getattr_chain_or({"b": "B"}),
        "getattr_chain_third": getattr_chain_or({}),
        "literal_or_getattr": literal_or_getattr({"k": "val"}),
        "getattr_and_truthy": getattr_and_true({"flag": 1}),
        "getattr_and_falsy": getattr_and_true({"flag": 0}),
        "getattr_alone_hit": getattr_alone({"k": "present"}),
        "getattr_alone_miss": getattr_alone({}),
        "dict_get_poly_hit": dict_get_or_empty({"k": "hi"}),
        "dict_get_poly_miss": dict_get_or_empty({}),
        "dict_get_one_arg_hit": dict_get_one_arg_or_empty({"k": "hi"}),
        "dict_get_one_arg_miss": dict_get_one_arg_or_empty({}),
        "dict_get_one_arg_falsy": dict_get_one_arg_or_empty({"k": ""}),
    };
}
