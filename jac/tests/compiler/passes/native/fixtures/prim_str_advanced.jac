"""String advanced method primitives: capitalize, swapcase, count, lstrip, rstrip,
removeprefix, removesuffix, replace, isalpha, isdigit, isalnum, isspace,
islower, isupper, isascii, isprintable, casefold, isdecimal.

Cross-backend equivalence fixture — Python reference + native implementation.
"""

def str_advanced_py() -> dict {
    return {
        # Case conversion
        "capitalize_hello": "hello world".capitalize(),
        "capitalize_upper": "HELLO".capitalize(),
        "capitalize_empty": "".capitalize(),
        "capitalize_single": "a".capitalize(),
        "swapcase_mixed": "Hello World".swapcase(),
        "swapcase_lower": "hello".swapcase(),
        "swapcase_upper": "HELLO".swapcase(),
        "casefold_upper": "HELLO".casefold(),
        "casefold_mixed": "HeLLo".casefold(),
        # Search
        "count_basic": "hello world hello".count("hello"),
        "count_single": "abcabc".count("a"),
        "count_none": "hello".count("xyz"),
        "count_overlap": "aaa".count("aa"),
        # Strip variants
        "lstrip_spaces": "   hello   ".lstrip(),
        "lstrip_tabs": "\t\nhello\t\n".lstrip(),
        "rstrip_spaces": "   hello   ".rstrip(),
        "rstrip_tabs": "\t\nhello\t\n".rstrip(),
        # Remove prefix/suffix
        "removeprefix_match": "hello world".removeprefix("hello "),
        "removeprefix_nomatch": "hello world".removeprefix("xyz"),
        "removeprefix_empty": "hello".removeprefix(""),
        "removesuffix_match": "hello world".removesuffix(" world"),
        "removesuffix_nomatch": "hello world".removesuffix("xyz"),
        "removesuffix_empty": "hello".removesuffix(""),
        # Replace
        "replace_basic": "hello world".replace("world", "python"),
        "replace_multi": "aabaa".replace("a", "x"),
        "replace_nomatch": "hello".replace("xyz", "abc"),
        # Character tests
        "isalpha_true": 1 if "hello".isalpha() else 0,
        "isalpha_false": 1 if "hello123".isalpha() else 0,
        "isalpha_empty": 1 if "".isalpha() else 0,
        "isdigit_true": 1 if "12345".isdigit() else 0,
        "isdigit_false": 1 if "123a".isdigit() else 0,
        "isdigit_empty": 1 if "".isdigit() else 0,
        "isalnum_true": 1 if "hello123".isalnum() else 0,
        "isalnum_false": 1 if "hello 123".isalnum() else 0,
        "isspace_true": 1 if "   \t\n".isspace() else 0,
        "isspace_false": 1 if "  a  ".isspace() else 0,
        "isspace_empty": 1 if "".isspace() else 0,
        "islower_true": 1 if "hello".islower() else 0,
        "islower_false": 1 if "Hello".islower() else 0,
        "islower_digits": 1 if "hello123".islower() else 0,
        "isupper_true": 1 if "HELLO".isupper() else 0,
        "isupper_false": 1 if "Hello".isupper() else 0,
        "isupper_digits": 1 if "HELLO123".isupper() else 0,
        "isascii_true": 1 if "hello".isascii() else 0,
        "isascii_empty": 1 if "".isascii() else 0,
        "isprintable_true": 1 if "hello world".isprintable() else 0,
        "isprintable_empty": 1 if "".isprintable() else 0,
        "isdecimal_true": 1 if "12345".isdecimal() else 0,
        "isdecimal_false": 1 if "12.3".isdecimal() else 0
    };
}

na {
    def str_advanced_na() -> dict[str, any] {
        return {
            # Case conversion
            "capitalize_hello": "hello world".capitalize(),
            "capitalize_upper": "HELLO".capitalize(),
            "capitalize_empty": "".capitalize(),
            "capitalize_single": "a".capitalize(),
            "swapcase_mixed": "Hello World".swapcase(),
            "swapcase_lower": "hello".swapcase(),
            "swapcase_upper": "HELLO".swapcase(),
            "casefold_upper": "HELLO".casefold(),
            "casefold_mixed": "HeLLo".casefold(),
            # Search
            "count_basic": "hello world hello".count("hello"),
            "count_single": "abcabc".count("a"),
            "count_none": "hello".count("xyz"),
            "count_overlap": "aaa".count("aa"),
            # Strip variants
            "lstrip_spaces": "   hello   ".lstrip(),
            "lstrip_tabs": "\t\nhello\t\n".lstrip(),
            "rstrip_spaces": "   hello   ".rstrip(),
            "rstrip_tabs": "\t\nhello\t\n".rstrip(),
            # Remove prefix/suffix
            "removeprefix_match": "hello world".removeprefix("hello "),
            "removeprefix_nomatch": "hello world".removeprefix("xyz"),
            "removeprefix_empty": "hello".removeprefix(""),
            "removesuffix_match": "hello world".removesuffix(" world"),
            "removesuffix_nomatch": "hello world".removesuffix("xyz"),
            "removesuffix_empty": "hello".removesuffix(""),
            # Replace
            "replace_basic": "hello world".replace("world", "python"),
            "replace_multi": "aabaa".replace("a", "x"),
            "replace_nomatch": "hello".replace("xyz", "abc"),
            # Character tests
            "isalpha_true": 1 if "hello".isalpha() else 0,
            "isalpha_false": 1 if "hello123".isalpha() else 0,
            "isalpha_empty": 1 if "".isalpha() else 0,
            "isdigit_true": 1 if "12345".isdigit() else 0,
            "isdigit_false": 1 if "123a".isdigit() else 0,
            "isdigit_empty": 1 if "".isdigit() else 0,
            "isalnum_true": 1 if "hello123".isalnum() else 0,
            "isalnum_false": 1 if "hello 123".isalnum() else 0,
            "isspace_true": 1 if "   \t\n".isspace() else 0,
            "isspace_false": 1 if "  a  ".isspace() else 0,
            "isspace_empty": 1 if "".isspace() else 0,
            "islower_true": 1 if "hello".islower() else 0,
            "islower_false": 1 if "Hello".islower() else 0,
            "islower_digits": 1 if "hello123".islower() else 0,
            "isupper_true": 1 if "HELLO".isupper() else 0,
            "isupper_false": 1 if "Hello".isupper() else 0,
            "isupper_digits": 1 if "HELLO123".isupper() else 0,
            "isascii_true": 1 if "hello".isascii() else 0,
            "isascii_empty": 1 if "".isascii() else 0,
            "isprintable_true": 1 if "hello world".isprintable() else 0,
            "isprintable_empty": 1 if "".isprintable() else 0,
            "isdecimal_true": 1 if "12345".isdecimal() else 0,
            "isdecimal_false": 1 if "12.3".isdecimal() else 0
        };
    }
}
