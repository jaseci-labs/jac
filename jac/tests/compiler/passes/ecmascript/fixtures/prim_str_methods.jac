"""String method primitives: case, search, modify, split/join, alignment, char tests."""

def str_methods_py() -> dict {
    s1: str = "HELLO WORLD";
    s2: str = "hello world";
    s3: str = "  Hello, World!  ";
    s4: str = "hello world hello";
    csv: str = "a,b,c";
    short: str = "hi";
    alnum: str = "abc123";
    spaces: str = "   ";
    sep: str = ",";
    items: list = ["x", "y", "z"];

    return {
        # Case conversion
        "lower": s1.lower(),
        "upper": s2.upper(),
        "casefold": s1.casefold(),

        # Search
        "find": s2.find("world"),
        "find_miss": s2.find("xyz"),
        "rfind": s4.rfind("hello"),
        "startswith_t": s2.startswith("hello"),
        "startswith_f": s2.startswith("world"),
        "endswith_t": s2.endswith("world"),
        "endswith_f": s2.endswith("hello"),

        # Modification
        "replace": s2.replace("world", "jac"),
        "strip": s3.strip(),
        "lstrip": s3.lstrip(),
        "rstrip": s3.rstrip(),

        # Split and join
        "split": csv.split(","),
        "join": sep.join(items),

        # Alignment
        "ljust": short.ljust(10),
        "rjust": short.rjust(10),

        # Character tests
        "isalnum_t": alnum.isalnum(),
        "isalpha_t": "abc".isalpha(),
        "isalpha_f": alnum.isalpha(),
        "isascii_t": s2.isascii(),
        "isdecimal_t": "123".isdecimal(),
        "isdecimal_f": "12.3".isdecimal(),
        "isdigit_t": "456".isdigit(),
        "isdigit_f": "45x".isdigit(),
        "isidentifier_t": "my_var".isidentifier(),
        "isidentifier_f": "3bad".isidentifier(),
        "islower_t": s2.islower(),
        "islower_f": s1.islower(),
        "isupper_t": s1.isupper(),
        "isupper_f": s2.isupper(),
        "isspace_t": spaces.isspace(),
        "isspace_f": s2.isspace(),
        "isprintable_t": s2.isprintable(),

        # Comparison operators
        "eq_t": s2 == "hello world",
        "eq_f": s2 == "other",
        "ne_t": s2 != "other",
        "lt": "abc" < "xyz",
        "gt": "xyz" > "abc",
        "le": "abc" <= "abc",
        "ge": "xyz" >= "abc"
    };
}

cl def str_methods_cl() -> dict {
    s1: str = "HELLO WORLD";
    s2: str = "hello world";
    s3: str = "  Hello, World!  ";
    s4: str = "hello world hello";
    csv: str = "a,b,c";
    short: str = "hi";
    alnum: str = "abc123";
    spaces: str = "   ";
    sep: str = ",";
    items: list = ["x", "y", "z"];

    return {
        # Case conversion
        "lower": s1.lower(),
        "upper": s2.upper(),
        "casefold": s1.casefold(),

        # Search
        "find": s2.find("world"),
        "find_miss": s2.find("xyz"),
        "rfind": s4.rfind("hello"),
        "startswith_t": s2.startswith("hello"),
        "startswith_f": s2.startswith("world"),
        "endswith_t": s2.endswith("world"),
        "endswith_f": s2.endswith("hello"),

        # Modification
        "replace": s2.replace("world", "jac"),
        "strip": s3.strip(),
        "lstrip": s3.lstrip(),
        "rstrip": s3.rstrip(),

        # Split and join
        "split": csv.split(","),
        "join": sep.join(items),

        # Alignment
        "ljust": short.ljust(10),
        "rjust": short.rjust(10),

        # Character tests
        "isalnum_t": alnum.isalnum(),
        "isalpha_t": "abc".isalpha(),
        "isalpha_f": alnum.isalpha(),
        "isascii_t": s2.isascii(),
        "isdecimal_t": "123".isdecimal(),
        "isdecimal_f": "12.3".isdecimal(),
        "isdigit_t": "456".isdigit(),
        "isdigit_f": "45x".isdigit(),
        "isidentifier_t": "my_var".isidentifier(),
        "isidentifier_f": "3bad".isidentifier(),
        "islower_t": s2.islower(),
        "islower_f": s1.islower(),
        "isupper_t": s1.isupper(),
        "isupper_f": s2.isupper(),
        "isspace_t": spaces.isspace(),
        "isspace_f": s2.isspace(),
        "isprintable_t": s2.isprintable(),

        # Comparison operators
        "eq_t": s2 == "hello world",
        "eq_f": s2 == "other",
        "ne_t": s2 != "other",
        "lt": "abc" < "xyz",
        "gt": "xyz" > "abc",
        "le": "abc" <= "abc",
        "ge": "xyz" >= "abc"
    };
}
