"""String index, rindex, center, isidentifier, istitle primitives.

Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def str_index_py() -> dict {
    return {
        # index (first occurrence)
        "index_basic": "hello world".index("world"),
        "index_start": "hello world".index("o"),
        "index_char": "abcdef".index("d"),
        # rindex (last occurrence)
        "rindex_basic": "hello world hello".rindex("hello"),
        "rindex_single": "abcabc".rindex("b"),
        "rindex_start": "hello".rindex("h"),
        # center
        "center_wide": "hi".center(10),
        "center_exact": "hello".center(5),
        "center_narrow": "hello world".center(3),
        "center_odd": "ab".center(7),
        # isidentifier
        "isid_valid": 1 if "hello".isidentifier() else 0,
        "isid_underscore": 1 if "_var".isidentifier() else 0,
        "isid_alnum": 1 if "var123".isidentifier() else 0,
        "isid_digit_start": 1 if "123abc".isidentifier() else 0,
        "isid_empty": 1 if "".isidentifier() else 0,
        "isid_space": 1 if "hello world".isidentifier() else 0,
        "isid_single": 1 if "x".isidentifier() else 0,
        # istitle
        "istitle_true": 1 if "Hello World".istitle() else 0,
        "istitle_false": 1 if "hello world".istitle() else 0,
        "istitle_single": 1 if "Hello".istitle() else 0,
        "istitle_allupper": 1 if "HELLO".istitle() else 0,
        "istitle_mixed": 1 if "Hello world".istitle() else 0,
        "istitle_num": 1 if "Hello 123 World".istitle() else 0,
        "istitle_empty": 1 if "".istitle() else 0
    };
}

na {
    def str_index_na() -> dict[str, any] {
        return {
            # index (first occurrence)
            "index_basic": "hello world".index("world"),
            "index_start": "hello world".index("o"),
            "index_char": "abcdef".index("d"),
            # rindex (last occurrence)
            "rindex_basic": "hello world hello".rindex("hello"),
            "rindex_single": "abcabc".rindex("b"),
            "rindex_start": "hello".rindex("h"),
            # center
            "center_wide": "hi".center(10),
            "center_exact": "hello".center(5),
            "center_narrow": "hello world".center(3),
            "center_odd": "ab".center(7),
            # isidentifier
            "isid_valid": 1 if "hello".isidentifier() else 0,
            "isid_underscore": 1 if "_var".isidentifier() else 0,
            "isid_alnum": 1 if "var123".isidentifier() else 0,
            "isid_digit_start": 1 if "123abc".isidentifier() else 0,
            "isid_empty": 1 if "".isidentifier() else 0,
            "isid_space": 1 if "hello world".isidentifier() else 0,
            "isid_single": 1 if "x".isidentifier() else 0,
            # istitle
            "istitle_true": 1 if "Hello World".istitle() else 0,
            "istitle_false": 1 if "hello world".istitle() else 0,
            "istitle_single": 1 if "Hello".istitle() else 0,
            "istitle_allupper": 1 if "HELLO".istitle() else 0,
            "istitle_mixed": 1 if "Hello world".istitle() else 0,
            "istitle_num": 1 if "Hello 123 World".istitle() else 0,
            "istitle_empty": 1 if "".istitle() else 0
        };
    }
}
