"""String operators: in, *, and expandtabs.

Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def str_ops_py() -> dict {
    return {
        # str in operator
        "in_found": 1 if "world" in "hello world" else 0,
        "in_not_found": 1 if "xyz" in "hello world" else 0,
        "in_empty_sub": 1 if "" in "hello" else 0,
        "in_char": 1 if "l" in "hello" else 0,
        "not_in_found": 1 if "world" not in "hello world" else 0,
        "not_in_missing": 1 if "xyz" not in "hello world" else 0,
        # str * operator (repeat)
        "repeat_3": "ab" * 3,
        "repeat_1": "hello" * 1,
        "repeat_0": "test" * 0,
        "repeat_rhs": 2 * "xy",
        # expandtabs
        "et_default": "a\tb".expandtabs(),
        "et_4": "a\tb".expandtabs(4),
        "et_no_tab": "hello".expandtabs(),
        "et_multi": "a\tb\tc".expandtabs(4),
        "et_newline": "a\tb\na\tb".expandtabs(4)
    };
}

na {
    def str_ops_na() -> dict[str, any] {
        return {
            # str in operator
            "in_found": 1 if "world" in "hello world" else 0,
            "in_not_found": 1 if "xyz" in "hello world" else 0,
            "in_empty_sub": 1 if "" in "hello" else 0,
            "in_char": 1 if "l" in "hello" else 0,
            "not_in_found": 1 if "world" not in "hello world" else 0,
            "not_in_missing": 1 if "xyz" not in "hello world" else 0,
            # str * operator (repeat)
            "repeat_3": "ab" * 3,
            "repeat_1": "hello" * 1,
            "repeat_0": "test" * 0,
            "repeat_rhs": 2 * "xy",
            # expandtabs
            "et_default": "a\tb".expandtabs(),
            "et_4": "a\tb".expandtabs(4),
            "et_no_tab": "hello".expandtabs(),
            "et_multi": "a\tb\tc".expandtabs(4),
            "et_newline": "a\tb\na\tb".expandtabs(4)
        };
    }
}
