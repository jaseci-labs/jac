"""Bytes method primitives — all 32 BytesEmitter interfaces.

Split into 4 function pairs by category.
All bytes results converted to list(bytes) for JSON serialization.
Uses bytes([...]) constructor since b"" literals may not be available in cl def.
"""

# ---- Search & encoding methods ----

def bytes_search_py() -> dict {
    b = bytes([104, 101, 108, 108, 111]);  # b"hello"
    sub = bytes([108, 108]);  # b"ll"

    # decode
    decoded: str = b.decode();

    # hex
    hx: str = b.hex();

    # fromhex (static method)
    from_hx: list = list(bytes.fromhex("68656c6c6f"));

    # count
    count_l: int = b.count(bytes([108]));
    count_miss: int = b.count(bytes([120]));

    # find / rfind
    find_hit: int = b.find(sub);
    find_miss: int = b.find(bytes([120]));
    rfind_hit: int = b.rfind(bytes([108]));

    # index / rindex
    idx: int = b.index(sub);
    ridx: int = b.rindex(bytes([108]));

    # startswith / endswith
    sw_yes: bool = b.startswith(bytes([104, 101]));
    sw_no: bool = b.startswith(bytes([111]));
    ew_yes: bool = b.endswith(bytes([108, 111]));
    ew_no: bool = b.endswith(bytes([104]));

    return {
        "decoded": decoded, "hex": hx,
        "from_hex": from_hx,
        "count_l": count_l, "count_miss": count_miss,
        "find_hit": find_hit, "find_miss": find_miss,
        "rfind_hit": rfind_hit,
        "idx": idx, "ridx": ridx,
        "sw_yes": sw_yes, "sw_no": sw_no,
        "ew_yes": ew_yes, "ew_no": ew_no
    };
}

cl def bytes_search_cl() -> dict {
    b = bytes([104, 101, 108, 108, 111]);
    sub = bytes([108, 108]);

    decoded: str = b.decode();
    hx: str = b.hex();
    from_hx: list = list(bytes.fromhex("68656c6c6f"));
    count_l: int = b.count(bytes([108]));
    count_miss: int = b.count(bytes([120]));
    find_hit: int = b.find(sub);
    find_miss: int = b.find(bytes([120]));
    rfind_hit: int = b.rfind(bytes([108]));
    idx: int = b.index(sub);
    ridx: int = b.rindex(bytes([108]));
    sw_yes: bool = b.startswith(bytes([104, 101]));
    sw_no: bool = b.startswith(bytes([111]));
    ew_yes: bool = b.endswith(bytes([108, 111]));
    ew_no: bool = b.endswith(bytes([104]));

    return {
        "decoded": decoded, "hex": hx,
        "from_hex": from_hx,
        "count_l": count_l, "count_miss": count_miss,
        "find_hit": find_hit, "find_miss": find_miss,
        "rfind_hit": rfind_hit,
        "idx": idx, "ridx": ridx,
        "sw_yes": sw_yes, "sw_no": sw_no,
        "ew_yes": ew_yes, "ew_no": ew_no
    };
}

# ---- Modification methods ----

def bytes_modify_py() -> dict {
    b = bytes([104, 101, 108, 108, 111]);  # b"hello"

    # replace
    replaced: list = list(b.replace(bytes([108]), bytes([76])));

    # strip / lstrip / rstrip
    padded = bytes([32, 104, 105, 32]);
    stripped: list = list(padded.strip());
    lstripped: list = list(padded.lstrip());
    rstripped: list = list(padded.rstrip());

    # removeprefix / removesuffix
    rp: list = list(b.removeprefix(bytes([104, 101])));
    rs: list = list(b.removesuffix(bytes([108, 111])));

    # split / rsplit
    data = bytes([97, 44, 98, 44, 99]);  # b"a,b,c"
    sep = bytes([44]);  # b","
    split_r: list = [list(chunk) for chunk in data.split(sep)];
    rsplit_r: list = [list(chunk) for chunk in data.rsplit(sep)];

    # splitlines
    lines = bytes([97, 10, 98, 10, 99]);  # b"a\nb\nc"
    splitlines_r: list = [list(line) for line in lines.splitlines()];

    # join
    joined: list = list(sep.join([bytes([97]), bytes([98]), bytes([99])]));

    # partition / rpartition
    p: list = [list(x) for x in data.partition(sep)];
    rp2: list = [list(x) for x in data.rpartition(sep)];

    return {
        "replaced": replaced,
        "stripped": stripped, "lstripped": lstripped, "rstripped": rstripped,
        "removeprefix": rp, "removesuffix": rs,
        "split": split_r, "rsplit": rsplit_r,
        "splitlines": splitlines_r,
        "joined": joined,
        "partition": p, "rpartition": rp2
    };
}

cl def bytes_modify_cl() -> dict {
    b = bytes([104, 101, 108, 108, 111]);

    replaced: list = list(b.replace(bytes([108]), bytes([76])));

    padded = bytes([32, 104, 105, 32]);
    stripped: list = list(padded.strip());
    lstripped: list = list(padded.lstrip());
    rstripped: list = list(padded.rstrip());

    rp: list = list(b.removeprefix(bytes([104, 101])));
    rs: list = list(b.removesuffix(bytes([108, 111])));

    data = bytes([97, 44, 98, 44, 99]);
    sep = bytes([44]);
    # Extract method calls from comprehensions for proper type dispatch
    split_raw = data.split(sep);
    split_r: list = [list(chunk) for chunk in split_raw];
    rsplit_raw = data.rsplit(sep);
    rsplit_r: list = [list(chunk) for chunk in rsplit_raw];

    lines = bytes([97, 10, 98, 10, 99]);
    lines_raw = lines.splitlines();
    splitlines_r: list = [list(line) for line in lines_raw];

    joined: list = list(sep.join([bytes([97]), bytes([98]), bytes([99])]));

    p_raw = data.partition(sep);
    p: list = [list(x) for x in p_raw];
    rp2_raw = data.rpartition(sep);
    rp2: list = [list(x) for x in rp2_raw];

    return {
        "replaced": replaced,
        "stripped": stripped, "lstripped": lstripped, "rstripped": rstripped,
        "removeprefix": rp, "removesuffix": rs,
        "split": split_r, "rsplit": rsplit_r,
        "splitlines": splitlines_r,
        "joined": joined,
        "partition": p, "rpartition": rp2
    };
}

# ---- Case & alignment methods ----

def bytes_case_py() -> dict {
    b = bytes([104, 101, 108, 108, 111]);  # b"hello"

    cap: list = list(b.capitalize());
    lower: list = list(b.lower());
    upper: list = list(b.upper());
    title: list = list(bytes([104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]).title());
    swap: list = list(bytes([72, 101, 76, 76, 79]).swapcase());

    # alignment (pad with space=32)
    center: list = list(b.center(9));
    ljust: list = list(b.ljust(8));
    rjust: list = list(b.rjust(8));
    zfill: list = list(bytes([52, 50]).zfill(5));

    # expandtabs
    tabbed = bytes([97, 9, 98]);  # b"a\tb"
    et: list = list(tabbed.expandtabs(4));

    # translate + maketrans
    tbl = bytes.maketrans(bytes([104]), bytes([72]));
    tr: list = list(b.translate(tbl));

    return {
        "cap": cap, "lower": lower, "upper": upper,
        "title": title, "swap": swap,
        "center": center, "ljust": ljust, "rjust": rjust,
        "zfill": zfill, "expandtabs": et,
        "translate": tr
    };
}

cl def bytes_case_cl() -> dict {
    b = bytes([104, 101, 108, 108, 111]);

    cap: list = list(b.capitalize());
    lower: list = list(b.lower());
    upper: list = list(b.upper());
    title: list = list(bytes([104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]).title());
    swap: list = list(bytes([72, 101, 76, 76, 79]).swapcase());

    center: list = list(b.center(9));
    ljust: list = list(b.ljust(8));
    rjust: list = list(b.rjust(8));
    zfill: list = list(bytes([52, 50]).zfill(5));

    tabbed = bytes([97, 9, 98]);
    et: list = list(tabbed.expandtabs(4));

    tbl = bytes.maketrans(bytes([104]), bytes([72]));
    tr: list = list(b.translate(tbl));

    return {
        "cap": cap, "lower": lower, "upper": upper,
        "title": title, "swap": swap,
        "center": center, "ljust": ljust, "rjust": rjust,
        "zfill": zfill, "expandtabs": et,
        "translate": tr
    };
}

# ---- Boolean test methods ----

def bytes_test_py() -> dict {
    alpha = bytes([97, 98, 99]);  # b"abc"
    digit = bytes([49, 50, 51]);  # b"123"
    mixed = bytes([97, 49]);  # b"a1"
    space = bytes([32, 9, 10]);  # b" \t\n"
    upper_b = bytes([65, 66]);  # b"AB"
    lower_b = bytes([97, 98]);  # b"ab"
    title_b = bytes([72, 101, 108, 108, 111]);  # b"Hello"
    empty = bytes([]);

    alnum_alpha: bool = alpha.isalnum();
    alnum_digit: bool = digit.isalnum();
    alnum_mixed: bool = mixed.isalnum();
    alnum_space: bool = space.isalnum();

    is_alpha: bool = alpha.isalpha();
    is_alpha_no: bool = digit.isalpha();

    is_ascii: bool = alpha.isascii();
    is_ascii_empty: bool = empty.isascii();

    is_digit: bool = digit.isdigit();
    is_digit_no: bool = alpha.isdigit();

    is_lower: bool = lower_b.islower();
    is_lower_no: bool = upper_b.islower();

    is_upper: bool = upper_b.isupper();
    is_upper_no: bool = lower_b.isupper();

    is_space: bool = space.isspace();
    is_space_no: bool = alpha.isspace();

    is_title: bool = title_b.istitle();
    is_title_no: bool = alpha.istitle();

    return {
        "alnum_alpha": alnum_alpha, "alnum_digit": alnum_digit,
        "alnum_mixed": alnum_mixed, "alnum_space": alnum_space,
        "is_alpha": is_alpha, "is_alpha_no": is_alpha_no,
        "is_ascii": is_ascii, "is_ascii_empty": is_ascii_empty,
        "is_digit": is_digit, "is_digit_no": is_digit_no,
        "is_lower": is_lower, "is_lower_no": is_lower_no,
        "is_upper": is_upper, "is_upper_no": is_upper_no,
        "is_space": is_space, "is_space_no": is_space_no,
        "is_title": is_title, "is_title_no": is_title_no
    };
}

cl def bytes_test_cl() -> dict {
    alpha = bytes([97, 98, 99]);
    digit = bytes([49, 50, 51]);
    mixed = bytes([97, 49]);
    space = bytes([32, 9, 10]);
    upper_b = bytes([65, 66]);
    lower_b = bytes([97, 98]);
    title_b = bytes([72, 101, 108, 108, 111]);
    empty = bytes([]);

    alnum_alpha: bool = alpha.isalnum();
    alnum_digit: bool = digit.isalnum();
    alnum_mixed: bool = mixed.isalnum();
    alnum_space: bool = space.isalnum();

    is_alpha: bool = alpha.isalpha();
    is_alpha_no: bool = digit.isalpha();

    is_ascii: bool = alpha.isascii();
    is_ascii_empty: bool = empty.isascii();

    is_digit: bool = digit.isdigit();
    is_digit_no: bool = alpha.isdigit();

    is_lower: bool = lower_b.islower();
    is_lower_no: bool = upper_b.islower();

    is_upper: bool = upper_b.isupper();
    is_upper_no: bool = lower_b.isupper();

    is_space: bool = space.isspace();
    is_space_no: bool = alpha.isspace();

    is_title: bool = title_b.istitle();
    is_title_no: bool = alpha.istitle();

    return {
        "alnum_alpha": alnum_alpha, "alnum_digit": alnum_digit,
        "alnum_mixed": alnum_mixed, "alnum_space": alnum_space,
        "is_alpha": is_alpha, "is_alpha_no": is_alpha_no,
        "is_ascii": is_ascii, "is_ascii_empty": is_ascii_empty,
        "is_digit": is_digit, "is_digit_no": is_digit_no,
        "is_lower": is_lower, "is_lower_no": is_lower_no,
        "is_upper": is_upper, "is_upper_no": is_upper_no,
        "is_space": is_space, "is_space_no": is_space_no,
        "is_title": is_title, "is_title_no": is_title_no
    };
}
