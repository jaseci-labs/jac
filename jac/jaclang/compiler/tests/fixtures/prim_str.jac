"""Str emitter: all 8 subsections merged.

Cross-backend equivalence fixture.
Covers: case, search, modify, split/join, alignment, char tests, comparisons,
operators (in, *, expandtabs), index/rindex/center, partition/splitlines/rsplit,
format_map, translate, title, rfind, zfill.
"""

# --- All string methods and operators ---
def str_py() -> dict {
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

    # format_map
    fm1: str = "{name} is {age}".format_map({"name": "Bob", "age": "30"});
    fm2: str = "{x}{y}{x}".format_map({"x": "a", "y": "b"});

    # expandtabs
    tab: str = chr(9);
    et1: str = ("a" + tab + "b" + tab + "c").expandtabs(4);
    et2: str = (tab + tab).expandtabs(8);
    et3: str = "no tabs here".expandtabs(4);

    # translate
    table = str.maketrans("helo", "HELO");
    tr1: str = "hello world".translate(table);

    # % operator
    mod1: str = "Hello %s" % "world";
    mod2: str = "Value: %d" % 42;

    # encode
    enc1: list = list("hello".encode());
    enc2: list = list("".encode());

    # partition
    p1: list[str] = list("hello world".partition(" "));
    p2: list[str] = list("hello".partition("x"));
    rp1: list[str] = list("hello world foo".rpartition(" "));
    rp2: list[str] = list("hello".rpartition("x"));
    sl: list[str] = "a\nb\nc".splitlines();
    rs: list[str] = "a b c".rsplit(" ");

    # join
    words: list[str] = ["hello", "world", "foo"];
    joined: str = "-".join(words);
    comma_joined: str = ", ".join(words);
    empty_sep_j: str = "".join(words);
    single: list[str] = ["only"];
    single_joined: str = ",".join(single);

    return {
        # case
        "lower": s1.lower(),
        "upper": s2.upper(),
        "casefold": s1.casefold(),
        "capitalize_hello": "hello world".capitalize(),
        "capitalize_upper": "HELLO".capitalize(),
        "capitalize_empty": "".capitalize(),
        "capitalize_single": "a".capitalize(),
        "swapcase_mixed": "Hello World".swapcase(),
        "swapcase_lower": "hello".swapcase(),
        "swapcase_upper": "HELLO".swapcase(),
        "casefold_upper": "HELLO".casefold(),
        "casefold_mixed": "HeLLo".casefold(),
        # search
        "find": s2.find("world"),
        "find_miss": s2.find("xyz"),
        "rfind": s4.rfind("hello"),
        "startswith_t": s2.startswith("hello"),
        "startswith_f": s2.startswith("world"),
        "endswith_t": s2.endswith("world"),
        "endswith_f": s2.endswith("hello"),
        "count_basic": "hello world hello".count("hello"),
        "count_single": "abcabc".count("a"),
        "count_none": "hello".count("xyz"),
        "count_overlap": "aaa".count("aa"),
        # modify
        "replace": s2.replace("world", "jac"),
        "replace_basic": "hello world".replace("world", "python"),
        "replace_multi": "aabaa".replace("a", "x"),
        "replace_nomatch": "hello".replace("xyz", "abc"),
        "removeprefix_match": "hello world".removeprefix("hello "),
        "removeprefix_nomatch": "hello world".removeprefix("xyz"),
        "removeprefix_empty": "hello".removeprefix(""),
        "removesuffix_match": "hello world".removesuffix(" world"),
        "removesuffix_nomatch": "hello world".removesuffix("xyz"),
        "removesuffix_empty": "hello".removesuffix(""),
        # strip
        "strip": s3.strip(),
        "lstrip": s3.lstrip(),
        "rstrip": s3.rstrip(),
        "strip_tabs": "\thello\t".strip(),
        "lstrip_spaces": "   hello   ".lstrip(),
        "lstrip_tabs": "\t\nhello\t\n".lstrip(),
        "rstrip_spaces": "   hello   ".rstrip(),
        "rstrip_tabs": "\t\nhello\t\n".rstrip(),
        # split/join
        "split": csv.split(","),
        "join": sep.join(items),
        "split_len": len("a,b,c".split(",")),
        "split_space_len": len("hello world foo".split(" ")),
        # alignment
        "ljust": short.ljust(10),
        "rjust": short.rjust(10),
        # char tests
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
        "isdecimal_false": 1 if "12.3".isdecimal() else 0,
        # comparisons
        "eq_t": s2 == "hello world",
        "eq_f": s2 == "other",
        "ne_t": s2 != "other",
        "lt": "abc" < "xyz",
        "gt": "xyz" > "abc",
        "le": "abc" <= "abc",
        "ge": "xyz" >= "abc",
        "lt_abc_def": 1 if "abc" < "def" else 0,
        "lt_def_abc": 1 if "def" < "abc" else 0,
        "lt_same": 1 if "abc" < "abc" else 0,
        "lt_prefix": 1 if "abc" < "abcd" else 0,
        "lt_empty": 1 if "" < "a" else 0,
        "gt_abc_def": 1 if "abc" > "def" else 0,
        "gt_def_abc": 1 if "def" > "abc" else 0,
        "gt_same": 1 if "abc" > "abc" else 0,
        "gt_longer": 1 if "abcd" > "abc" else 0,
        "le_abc_def": 1 if "abc" <= "def" else 0,
        "le_same": 1 if "abc" <= "abc" else 0,
        "le_def_abc": 1 if "def" <= "abc" else 0,
        "ge_abc_def": 1 if "abc" >= "def" else 0,
        "ge_same": 1 if "abc" >= "abc" else 0,
        "ge_def_abc": 1 if "def" >= "abc" else 0,
        # concat, len, upper/lower mixed
        "concat": "hello" + " " + "world",
        "len_hello": len("hello"),
        "len_empty": len(""),
        "upper_mixed": "Hello World".upper(),
        "lower_mixed": "Hello World".lower(),
        "find_start": "hello world".find("hello"),
        "startswith_true": 1 if "hello world".startswith("hello") else 0,
        "startswith_false": 1 if "hello world".startswith("world") else 0,
        "endswith_true": 1 if "hello world".endswith("world") else 0,
        "endswith_false": 1 if "hello world".endswith("hello") else 0,
        # operators (in, *, expandtabs)
        "in_found": 1 if "world" in "hello world" else 0,
        "in_not_found": 1 if "xyz" in "hello world" else 0,
        "in_empty_sub": 1 if "" in "hello" else 0,
        "in_char": 1 if "l" in "hello" else 0,
        "not_in_found": 1 if "world" not in "hello world" else 0,
        "not_in_missing": 1 if "xyz" not in "hello world" else 0,
        "repeat_3": "ab" * 3,
        "repeat_1": "hello" * 1,
        "repeat_0": "test" * 0,
        "repeat_rhs": 2 * "xy",
        "et_default": "a\tb".expandtabs(),
        "et_4": "a\tb".expandtabs(4),
        "et_no_tab": "hello".expandtabs(),
        "et_multi": "a\tb\tc".expandtabs(4),
        "et_newline": "a\tb\na\tb".expandtabs(4),
        # index/rindex/center/isidentifier/istitle
        "index_basic": "hello world".index("world"),
        "index_start": "hello world".index("o"),
        "index_char": "abcdef".index("d"),
        "rindex_basic": "hello world hello".rindex("hello"),
        "rindex_single": "abcabc".rindex("b"),
        "rindex_start": "hello".rindex("h"),
        "center_wide": "hi".center(10),
        "center_exact": "hello".center(5),
        "center_narrow": "hello world".center(3),
        "center_odd": "ab".center(7),
        "isid_valid": 1 if "hello".isidentifier() else 0,
        "isid_underscore": 1 if "_var".isidentifier() else 0,
        "isid_alnum": 1 if "var123".isidentifier() else 0,
        "isid_digit_start": 1 if "123abc".isidentifier() else 0,
        "isid_empty": 1 if "".isidentifier() else 0,
        "isid_space": 1 if "hello world".isidentifier() else 0,
        "isid_single": 1 if "x".isidentifier() else 0,
        "istitle_true": 1 if "Hello World".istitle() else 0,
        "istitle_false": 1 if "hello world".istitle() else 0,
        "istitle_single": 1 if "Hello".istitle() else 0,
        "istitle_allupper": 1 if "HELLO".istitle() else 0,
        "istitle_mixed": 1 if "Hello world".istitle() else 0,
        "istitle_num": 1 if "Hello 123 World".istitle() else 0,
        "istitle_empty": 1 if "".istitle() else 0,
        # title, rfind variants, ljust/rjust/zfill
        "title_basic": "hello world".title(),
        "title_upper": "HELLO WORLD".title(),
        "title_mixed": "hELLO wORLD".title(),
        "title_single": "hello".title(),
        "title_empty": "".title(),
        "title_spaces": "hello  world".title(),
        "rfind_basic": "hello world hello".rfind("hello"),
        "rfind_single": "abcabc".rfind("abc"),
        "rfind_miss": "hello".rfind("xyz"),
        "rfind_start": "hello".rfind("hello"),
        "rfind_empty_sub": "hello".rfind(""),
        "ljust_pad": "hi".ljust(5),
        "ljust_exact": "hello".ljust(5),
        "ljust_nopad": "hello world".ljust(5),
        "rjust_pad": "hi".rjust(5),
        "rjust_exact": "hello".rjust(5),
        "rjust_nopad": "hello world".rjust(5),
        "zfill_pad": "42".zfill(5),
        "zfill_exact": "12345".zfill(5),
        "zfill_nopad": "123456".zfill(5),
        "zfill_neg": "-42".zfill(5),
        "zfill_plus": "+42".zfill(5),
        # format_map, translate, %, encode
        "fm1": fm1, "fm2": fm2,
        "et1": et1, "et2": et2, "et3": et3,
        "tr1": tr1,
        "mod1": mod1, "mod2": mod2,
        "enc1": enc1, "enc2": enc2,
        "encode_len": len("hello".encode()),
        "encode_empty_len": len("".encode()),
        # partition
        "p1_0": p1[0], "p1_1": p1[1], "p1_2": p1[2],
        "p2_0": p2[0], "p2_2": p2[2],
        "rp1_0": rp1[0], "rp1_1": rp1[1], "rp1_2": rp1[2],
        "rp2_0": rp2[0], "rp2_2": rp2[2],
        "sl_len": len(sl), "sl0": sl[0], "sl2": sl[2],
        "rs_len": len(rs), "rs0": rs[0], "rs2": rs[2],
        # join
        "joined": joined,
        "comma_joined": comma_joined,
        "empty_sep": empty_sep_j,
        "single_joined": single_joined,
        # isnumeric (emit_isnumeric) — SV/Python only
        "isnumeric_t": 1 if "123".isnumeric() else 0,
        "isnumeric_f": 1 if "12a".isnumeric() else 0,
        "isnumeric_empty": 1 if "".isnumeric() else 0,
        # str.format method (emit_format) — SV/Python only
        "fmt_pos_args": "x={} y={}".format(1, 2),
        "fmt_single": "hello {}".format("world"),
        "fmt_repeat": "{0} {0}".format("hi"),
        # str.format (shared with NA)
        "fmt_one": "hello {}".format("world"),
        "fmt_two": "{} and {}".format("foo", "bar"),
        "fmt_int": "x={}".format(42),
        "fmt_none": "no placeholders".format(),
        # string slicing
        "sslice_mid": "hello world"[3:7],
        "sslice_to": "hello world"[:5],
        "sslice_from": "hello world"[6:]
    };
}

cl def str_cl() -> dict {
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

    fm1: str = "{name} is {age}".format_map({"name": "Bob", "age": "30"});
    fm2: str = "{x}{y}{x}".format_map({"x": "a", "y": "b"});
    tab: str = chr(9);
    et1: str = ("a" + tab + "b" + tab + "c").expandtabs(4);
    et2: str = (tab + tab).expandtabs(8);
    et3: str = "no tabs here".expandtabs(4);
    table = str.maketrans("helo", "HELO");
    tr1: str = "hello world".translate(table);
    mod1: str = "Hello %s" % "world";
    mod2: str = "Value: %d" % 42;
    enc1: list = list("hello".encode());
    enc2: list = list("".encode());

    p1: list[str] = list("hello world".partition(" "));
    p2: list[str] = list("hello".partition("x"));
    rp1: list[str] = list("hello world foo".rpartition(" "));
    rp2: list[str] = list("hello".rpartition("x"));
    sl: list[str] = "a\nb\nc".splitlines();
    rs: list[str] = "a b c".rsplit(" ");

    words: list[str] = ["hello", "world", "foo"];
    joined: str = "-".join(words);
    comma_joined: str = ", ".join(words);
    empty_sep_j: str = "".join(words);
    single: list[str] = ["only"];
    single_joined: str = ",".join(single);

    return {
        "lower": s1.lower(),
        "upper": s2.upper(),
        "casefold": s1.casefold(),
        "capitalize_hello": "hello world".capitalize(),
        "capitalize_upper": "HELLO".capitalize(),
        "capitalize_empty": "".capitalize(),
        "capitalize_single": "a".capitalize(),
        "swapcase_mixed": "Hello World".swapcase(),
        "swapcase_lower": "hello".swapcase(),
        "swapcase_upper": "HELLO".swapcase(),
        "casefold_upper": "HELLO".casefold(),
        "casefold_mixed": "HeLLo".casefold(),
        "find": s2.find("world"),
        "find_miss": s2.find("xyz"),
        "rfind": s4.rfind("hello"),
        "startswith_t": s2.startswith("hello"),
        "startswith_f": s2.startswith("world"),
        "endswith_t": s2.endswith("world"),
        "endswith_f": s2.endswith("hello"),
        "count_basic": "hello world hello".count("hello"),
        "count_single": "abcabc".count("a"),
        "count_none": "hello".count("xyz"),
        "count_overlap": "aaa".count("aa"),
        "replace": s2.replace("world", "jac"),
        "replace_basic": "hello world".replace("world", "python"),
        "replace_multi": "aabaa".replace("a", "x"),
        "replace_nomatch": "hello".replace("xyz", "abc"),
        "removeprefix_match": "hello world".removeprefix("hello "),
        "removeprefix_nomatch": "hello world".removeprefix("xyz"),
        "removeprefix_empty": "hello".removeprefix(""),
        "removesuffix_match": "hello world".removesuffix(" world"),
        "removesuffix_nomatch": "hello world".removesuffix("xyz"),
        "removesuffix_empty": "hello".removesuffix(""),
        "strip": s3.strip(),
        "lstrip": s3.lstrip(),
        "rstrip": s3.rstrip(),
        "strip_tabs": "\thello\t".strip(),
        "lstrip_spaces": "   hello   ".lstrip(),
        "lstrip_tabs": "\t\nhello\t\n".lstrip(),
        "rstrip_spaces": "   hello   ".rstrip(),
        "rstrip_tabs": "\t\nhello\t\n".rstrip(),
        "split": csv.split(","),
        "join": sep.join(items),
        "split_len": len("a,b,c".split(",")),
        "split_space_len": len("hello world foo".split(" ")),
        "ljust": short.ljust(10),
        "rjust": short.rjust(10),
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
        "isdecimal_false": 1 if "12.3".isdecimal() else 0,
        "eq_t": s2 == "hello world",
        "eq_f": s2 == "other",
        "ne_t": s2 != "other",
        "lt": "abc" < "xyz",
        "gt": "xyz" > "abc",
        "le": "abc" <= "abc",
        "ge": "xyz" >= "abc",
        "lt_abc_def": 1 if "abc" < "def" else 0,
        "lt_def_abc": 1 if "def" < "abc" else 0,
        "lt_same": 1 if "abc" < "abc" else 0,
        "lt_prefix": 1 if "abc" < "abcd" else 0,
        "lt_empty": 1 if "" < "a" else 0,
        "gt_abc_def": 1 if "abc" > "def" else 0,
        "gt_def_abc": 1 if "def" > "abc" else 0,
        "gt_same": 1 if "abc" > "abc" else 0,
        "gt_longer": 1 if "abcd" > "abc" else 0,
        "le_abc_def": 1 if "abc" <= "def" else 0,
        "le_same": 1 if "abc" <= "abc" else 0,
        "le_def_abc": 1 if "def" <= "abc" else 0,
        "ge_abc_def": 1 if "abc" >= "def" else 0,
        "ge_same": 1 if "abc" >= "abc" else 0,
        "ge_def_abc": 1 if "def" >= "abc" else 0,
        "concat": "hello" + " " + "world",
        "len_hello": len("hello"),
        "len_empty": len(""),
        "upper_mixed": "Hello World".upper(),
        "lower_mixed": "Hello World".lower(),
        "find_start": "hello world".find("hello"),
        "startswith_true": 1 if "hello world".startswith("hello") else 0,
        "startswith_false": 1 if "hello world".startswith("world") else 0,
        "endswith_true": 1 if "hello world".endswith("world") else 0,
        "endswith_false": 1 if "hello world".endswith("hello") else 0,
        "in_found": 1 if "world" in "hello world" else 0,
        "in_not_found": 1 if "xyz" in "hello world" else 0,
        "in_empty_sub": 1 if "" in "hello" else 0,
        "in_char": 1 if "l" in "hello" else 0,
        "not_in_found": 1 if "world" not in "hello world" else 0,
        "not_in_missing": 1 if "xyz" not in "hello world" else 0,
        "repeat_3": "ab" * 3,
        "repeat_1": "hello" * 1,
        "repeat_0": "test" * 0,
        "repeat_rhs": 2 * "xy",
        "et_default": "a\tb".expandtabs(),
        "et_4": "a\tb".expandtabs(4),
        "et_no_tab": "hello".expandtabs(),
        "et_multi": "a\tb\tc".expandtabs(4),
        "et_newline": "a\tb\na\tb".expandtabs(4),
        "center_wide": "hi".center(10),
        "center_exact": "hello".center(5),
        "center_narrow": "hello world".center(3),
        "center_odd": "ab".center(7),
        "isid_valid": 1 if "hello".isidentifier() else 0,
        "isid_underscore": 1 if "_var".isidentifier() else 0,
        "isid_alnum": 1 if "var123".isidentifier() else 0,
        "isid_digit_start": 1 if "123abc".isidentifier() else 0,
        "isid_empty": 1 if "".isidentifier() else 0,
        "isid_space": 1 if "hello world".isidentifier() else 0,
        "isid_single": 1 if "x".isidentifier() else 0,
        "istitle_true": 1 if "Hello World".istitle() else 0,
        "istitle_false": 1 if "hello world".istitle() else 0,
        "istitle_single": 1 if "Hello".istitle() else 0,
        "istitle_allupper": 1 if "HELLO".istitle() else 0,
        "istitle_mixed": 1 if "Hello world".istitle() else 0,
        "istitle_num": 1 if "Hello 123 World".istitle() else 0,
        "istitle_empty": 1 if "".istitle() else 0,
        "title_basic": "hello world".title(),
        "title_upper": "HELLO WORLD".title(),
        "title_mixed": "hELLO wORLD".title(),
        "title_single": "hello".title(),
        "title_empty": "".title(),
        "title_spaces": "hello  world".title(),
        "rfind_basic": "hello world hello".rfind("hello"),
        "rfind_single": "abcabc".rfind("abc"),
        "rfind_miss": "hello".rfind("xyz"),
        "rfind_start": "hello".rfind("hello"),
        "rfind_empty_sub": "hello".rfind(""),
        "ljust_pad": "hi".ljust(5),
        "ljust_exact": "hello".ljust(5),
        "ljust_nopad": "hello world".ljust(5),
        "rjust_pad": "hi".rjust(5),
        "rjust_exact": "hello".rjust(5),
        "rjust_nopad": "hello world".rjust(5),
        "zfill_pad": "42".zfill(5),
        "zfill_exact": "12345".zfill(5),
        "zfill_nopad": "123456".zfill(5),
        "zfill_neg": "-42".zfill(5),
        "zfill_plus": "+42".zfill(5),
        "fm1": fm1, "fm2": fm2,
        "et1": et1, "et2": et2, "et3": et3,
        "tr1": tr1,
        "mod1": mod1, "mod2": mod2,
        "enc1": enc1, "enc2": enc2,
        "p1_0": p1[0], "p1_1": p1[1], "p1_2": p1[2],
        "p2_0": p2[0], "p2_2": p2[2],
        "rp1_0": rp1[0], "rp1_1": rp1[1], "rp1_2": rp1[2],
        "rp2_0": rp2[0], "rp2_2": rp2[2],
        "sl_len": len(sl), "sl0": sl[0], "sl2": sl[2],
        "rs_len": len(rs), "rs0": rs[0], "rs2": rs[2],
        "joined": joined,
        "comma_joined": comma_joined,
        "empty_sep": empty_sep_j,
        "single_joined": single_joined,
        # isnumeric (emit_isnumeric)
        "isnumeric_t": 1 if "123".isnumeric() else 0,
        "isnumeric_f": 1 if "12a".isnumeric() else 0,
        "isnumeric_empty": 1 if "".isnumeric() else 0,
        # str.format method (emit_format)
        "fmt_pos_args": "x={} y={}".format(1, 2),
        "fmt_single": "hello {}".format("world"),
        "fmt_repeat": "{0} {0}".format("hi")
    };
}

na {
    def str_na() -> dict[str, any] {
        s1: str = "  Hello, World!  ";
        s2: str = "\thello\t";
        s3: str = "a,b,c";
        s4: str = "hello world foo";
        s5: str = "hello world";
        s6: str = "HELLO WORLD";
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

        words: list[str] = ["hello", "world", "foo"];
        joined: str = "-".join(words);
        comma_joined: str = ", ".join(words);
        empty_sep_j: str = "".join(words);
        single: list[str] = ["only"];
        single_joined: str = ",".join(single);

        p1: list[str] = "hello world".partition(" ");
        p2: list[str] = "hello".partition("x");
        rp1: list[str] = "hello world foo".rpartition(" ");
        rp2: list[str] = "hello".rpartition("x");
        sl: list[str] = "a\nb\nc".splitlines();
        rs: list[str] = "a b c".rsplit(" ");

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
            "endswith_false": ew_false,
            # str_advanced_na
            "capitalize_hello": "hello world".capitalize(),
            "capitalize_upper": "HELLO".capitalize(),
            "capitalize_empty": "".capitalize(),
            "capitalize_single": "a".capitalize(),
            "swapcase_mixed": "Hello World".swapcase(),
            "swapcase_lower": "hello".swapcase(),
            "swapcase_upper": "HELLO".swapcase(),
            "casefold_upper": "HELLO".casefold(),
            "casefold_mixed": "HeLLo".casefold(),
            "count_basic": "hello world hello".count("hello"),
            "count_single": "abcabc".count("a"),
            "count_none": "hello".count("xyz"),
            "count_overlap": "aaa".count("aa"),
            "lstrip_spaces": "   hello   ".lstrip(),
            "lstrip_tabs": "\t\nhello\t\n".lstrip(),
            "rstrip_spaces": "   hello   ".rstrip(),
            "rstrip_tabs": "\t\nhello\t\n".rstrip(),
            "removeprefix_match": "hello world".removeprefix("hello "),
            "removeprefix_nomatch": "hello world".removeprefix("xyz"),
            "removeprefix_empty": "hello".removeprefix(""),
            "removesuffix_match": "hello world".removesuffix(" world"),
            "removesuffix_nomatch": "hello world".removesuffix("xyz"),
            "removesuffix_empty": "hello".removesuffix(""),
            "replace_basic": "hello world".replace("world", "python"),
            "replace_multi": "aabaa".replace("a", "x"),
            "replace_nomatch": "hello".replace("xyz", "abc"),
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
            "isdecimal_false": 1 if "12.3".isdecimal() else 0,
            # str_cmp_na
            "lt_abc_def": 1 if "abc" < "def" else 0,
            "lt_def_abc": 1 if "def" < "abc" else 0,
            "lt_same": 1 if "abc" < "abc" else 0,
            "lt_prefix": 1 if "abc" < "abcd" else 0,
            "lt_empty": 1 if "" < "a" else 0,
            "gt_abc_def": 1 if "abc" > "def" else 0,
            "gt_def_abc": 1 if "def" > "abc" else 0,
            "gt_same": 1 if "abc" > "abc" else 0,
            "gt_longer": 1 if "abcd" > "abc" else 0,
            "le_abc_def": 1 if "abc" <= "def" else 0,
            "le_same": 1 if "abc" <= "abc" else 0,
            "le_def_abc": 1 if "def" <= "abc" else 0,
            "ge_abc_def": 1 if "abc" >= "def" else 0,
            "ge_same": 1 if "abc" >= "abc" else 0,
            "ge_def_abc": 1 if "def" >= "abc" else 0,
            # str_ops_na
            "in_found": 1 if "world" in "hello world" else 0,
            "in_not_found": 1 if "xyz" in "hello world" else 0,
            "in_empty_sub": 1 if "" in "hello" else 0,
            "in_char": 1 if "l" in "hello" else 0,
            "not_in_found": 1 if "world" not in "hello world" else 0,
            "not_in_missing": 1 if "xyz" not in "hello world" else 0,
            "repeat_3": "ab" * 3,
            "repeat_1": "hello" * 1,
            "repeat_0": "test" * 0,
            "repeat_rhs": 2 * "xy",
            "et_default": "a\tb".expandtabs(),
            "et_4": "a\tb".expandtabs(4),
            "et_no_tab": "hello".expandtabs(),
            "et_multi": "a\tb\tc".expandtabs(4),
            "et_newline": "a\tb\na\tb".expandtabs(4),
            # str_index_na
            "index_basic": "hello world".index("world"),
            "index_start": "hello world".index("o"),
            "index_char": "abcdef".index("d"),
            "rindex_basic": "hello world hello".rindex("hello"),
            "rindex_single": "abcabc".rindex("b"),
            "rindex_start": "hello".rindex("h"),
            "center_wide": "hi".center(10),
            "center_exact": "hello".center(5),
            "center_narrow": "hello world".center(3),
            "center_odd": "ab".center(7),
            "isid_valid": 1 if "hello".isidentifier() else 0,
            "isid_underscore": 1 if "_var".isidentifier() else 0,
            "isid_alnum": 1 if "var123".isidentifier() else 0,
            "isid_digit_start": 1 if "123abc".isidentifier() else 0,
            "isid_empty": 1 if "".isidentifier() else 0,
            "isid_space": 1 if "hello world".isidentifier() else 0,
            "isid_single": 1 if "x".isidentifier() else 0,
            "istitle_true": 1 if "Hello World".istitle() else 0,
            "istitle_false": 1 if "hello world".istitle() else 0,
            "istitle_single": 1 if "Hello".istitle() else 0,
            "istitle_allupper": 1 if "HELLO".istitle() else 0,
            "istitle_mixed": 1 if "Hello world".istitle() else 0,
            "istitle_num": 1 if "Hello 123 World".istitle() else 0,
            "istitle_empty": 1 if "".istitle() else 0,
            # str_extra_na
            "title_basic": "hello world".title(),
            "title_upper": "HELLO WORLD".title(),
            "title_mixed": "hELLO wORLD".title(),
            "title_single": "hello".title(),
            "title_empty": "".title(),
            "title_spaces": "hello  world".title(),
            "rfind_basic": "hello world hello".rfind("hello"),
            "rfind_single": "abcabc".rfind("abc"),
            "rfind_miss": "hello".rfind("xyz"),
            "rfind_start": "hello".rfind("hello"),
            "rfind_empty_sub": "hello".rfind(""),
            "ljust_pad": "hi".ljust(5),
            "ljust_exact": "hello".ljust(5),
            "ljust_nopad": "hello world".ljust(5),
            "rjust_pad": "hi".rjust(5),
            "rjust_exact": "hello".rjust(5),
            "rjust_nopad": "hello world".rjust(5),
            "zfill_pad": "42".zfill(5),
            "zfill_exact": "12345".zfill(5),
            "zfill_nopad": "123456".zfill(5),
            "zfill_neg": "-42".zfill(5),
            "zfill_plus": "+42".zfill(5),
            # str_partition_na
            "p1_0": p1[0], "p1_1": p1[1], "p1_2": p1[2],
            "p2_0": p2[0], "p2_2": p2[2],
            "rp1_0": rp1[0], "rp1_1": rp1[1], "rp1_2": rp1[2],
            "rp2_0": rp2[0], "rp2_2": rp2[2],
            "sl_len": len(sl), "sl0": sl[0], "sl2": sl[2],
            "rs_len": len(rs), "rs0": rs[0], "rs2": rs[2],
            # str_join_na
            "joined": joined,
            "comma_joined": comma_joined,
            "empty_sep": empty_sep_j,
            "single_joined": single_joined,
            "encode_len": len("hello".encode()),
            "encode_empty_len": len("".encode()),
            # str.format
            "fmt_one": "hello {}".format("world"),
            "fmt_two": "{} and {}".format("foo", "bar"),
            "fmt_int": "x={}".format(42),
            "fmt_none": "no placeholders".format(),
            # string slicing
            "sslice_mid": "hello world"[3:7],
            "sslice_to": "hello world"[:5],
            "sslice_from": "hello world"[6:]
        };
    }
}
