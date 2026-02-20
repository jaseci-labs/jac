"""String method primitives: strip, split, upper, lower, find, startswith, endswith.

Cross-backend equivalence fixture — Python reference + native implementation.
"""

def str_methods_py() -> dict {
    return {
        "strip": "  hello  ".strip(),
        "strip_tabs": "\thello\t".strip(),
        "split_len": len("a,b,c".split(",")),
        "split_space_len": len("hello world foo".split(" ")),
        "concat": "hello" + " " + "world",
        "len_hello": len("hello"),
        "len_empty": len(""),
        "upper": "hello".upper(),
        "lower": "HELLO".lower(),
        "upper_mixed": "Hello World".upper(),
        "lower_mixed": "Hello World".lower(),
        "find_hit": "hello world".find("world"),
        "find_miss": "hello world".find("xyz"),
        "find_start": "hello world".find("hello"),
        "startswith_true": 1 if "hello world".startswith("hello") else 0,
        "startswith_false": 1 if "hello world".startswith("world") else 0,
        "endswith_true": 1 if "hello world".endswith("world") else 0,
        "endswith_false": 1 if "hello world".endswith("hello") else 0
    };
}

na {
    def str_methods_na() -> dict[str, any] {
        s1: str = "  hello  ";
        s2: str = "\thello\t";
        s3: str = "a,b,c";
        s4: str = "hello world foo";
        s5: str = "hello";
        s6: str = "HELLO";
        s7: str = "Hello World";
        s8: str = "hello world";
        parts1: list[str] = s3.split(",");
        parts2: list[str] = s4.split(" ");
        sw_true: int = 0;
        if s8.startswith("hello") { sw_true = 1; }
        sw_false: int = 0;
        if s8.startswith("world") { sw_false = 1; }
        ew_true: int = 0;
        if s8.endswith("world") { ew_true = 1; }
        ew_false: int = 0;
        if s8.endswith("hello") { ew_false = 1; }
        return {
            "strip": s1.strip(),
            "strip_tabs": s2.strip(),
            "split_len": len(parts1),
            "split_space_len": len(parts2),
            "concat": "hello" + " " + "world",
            "len_hello": len("hello"),
            "len_empty": len(""),
            "upper": s5.upper(),
            "lower": s6.lower(),
            "upper_mixed": s7.upper(),
            "lower_mixed": s7.lower(),
            "find_hit": s8.find("world"),
            "find_miss": s8.find("xyz"),
            "find_start": s8.find("hello"),
            "startswith_true": sw_true,
            "startswith_false": sw_false,
            "endswith_true": ew_true,
            "endswith_false": ew_false
        };
    }
}
