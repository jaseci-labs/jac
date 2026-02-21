"""Comprehensive tests for every _jac runtime namespace.

Each function pair (def + cl def) tests one namespace from jac_runtime_js.jac.
The def version runs on the Python backend; the cl def version compiles to JS
and exercises the _jac.* runtime calls.
"""

# =============================================================================
# int namespace: mod, bit_length, bit_count
# (to_bytes/from_bytes skipped — bytes are not JSON-serializable)
# =============================================================================

def jac_rt_int_py() -> dict {
    # mod — Python semantics: result sign matches divisor
    a: int = -7;
    b: int = 3;
    mod_np: int = a % b;        # 2
    c: int = 7;
    d: int = -3;
    mod_pn: int = c % d;        # -2
    e: int = -7;
    f: int = -3;
    mod_nn: int = e % f;        # -1
    mod_pp: int = 10 % 3;       # 1

    # bit_length
    n0: int = 0;
    bl_0: int = n0.bit_length();
    n5: int = 5;
    bl_5: int = n5.bit_length();
    n255: int = 255;
    bl_255: int = n255.bit_length();

    # bit_count
    n7: int = 7;
    bc_7: int = n7.bit_count();
    n10: int = 10;
    bc_10: int = n10.bit_count();
    bc_255: int = n255.bit_count();

    return {
        "mod_np": mod_np, "mod_pn": mod_pn,
        "mod_nn": mod_nn, "mod_pp": mod_pp,
        "bl_0": bl_0, "bl_5": bl_5, "bl_255": bl_255,
        "bc_7": bc_7, "bc_10": bc_10, "bc_255": bc_255
    };
}

cl def jac_rt_int_cl() -> dict {
    a: int = -7;
    b: int = 3;
    mod_np: int = a % b;
    c: int = 7;
    d: int = -3;
    mod_pn: int = c % d;
    e: int = -7;
    f: int = -3;
    mod_nn: int = e % f;
    mod_pp: int = 10 % 3;

    n0: int = 0;
    bl_0: int = n0.bit_length();
    n5: int = 5;
    bl_5: int = n5.bit_length();
    n255: int = 255;
    bl_255: int = n255.bit_length();

    n7: int = 7;
    bc_7: int = n7.bit_count();
    n10: int = 10;
    bc_10: int = n10.bit_count();
    bc_255: int = n255.bit_count();

    return {
        "mod_np": mod_np, "mod_pn": mod_pn,
        "mod_nn": mod_nn, "mod_pp": mod_pp,
        "bl_0": bl_0, "bl_5": bl_5, "bl_255": bl_255,
        "bc_7": bc_7, "bc_10": bc_10, "bc_255": bc_255
    };
}

# =============================================================================
# float namespace: mod, as_integer_ratio
# (hex/fromhex skipped — JS toString(16) differs from Python float.hex())
# =============================================================================

def jac_rt_float_py() -> dict {
    # mod — Python semantics for floats
    fa: float = -7.5;
    fb: float = 2.0;
    fmod1: float = fa % fb;       # 0.5

    # as_integer_ratio
    half: float = 0.5;
    ratio = half.as_integer_ratio();
    r0: int = ratio[0];
    r1: int = ratio[1];

    quarter: float = 0.25;
    ratio2 = quarter.as_integer_ratio();
    r2_0: int = ratio2[0];
    r2_1: int = ratio2[1];

    return {
        "fmod1": fmod1,
        "ratio_half": [r0, r1],
        "ratio_quarter": [r2_0, r2_1]
    };
}

cl def jac_rt_float_cl() -> dict {
    fa: float = -7.5;
    fb: float = 2.0;
    fmod1: float = fa % fb;

    half: float = 0.5;
    ratio = half.as_integer_ratio();
    r0: int = ratio[0];
    r1: int = ratio[1];

    quarter: float = 0.25;
    ratio2 = quarter.as_integer_ratio();
    r2_0: int = ratio2[0];
    r2_1: int = ratio2[1];

    return {
        "fmod1": fmod1,
        "ratio_half": [r0, r1],
        "ratio_quarter": [r2_0, r2_1]
    };
}

# =============================================================================
# str namespace: comprehensive string method coverage
# (translate/maketrans skipped — static method syntax differs)
# (format_map skipped — dict argument handling differs)
# =============================================================================

def jac_rt_str_py() -> dict {
    s: str = "hello world";

    # Case conversion
    cap: str = s.capitalize();
    ttl: str = s.title();
    swp: str = "Hello World".swapcase();

    # Search
    cnt: int = s.count("l");
    cnt_range: int = s.count("l", 0, 5);
    fnd: int = s.find("world");
    fnd_miss: int = s.find("xyz");
    rfnd: int = s.rfind("l");
    idx: int = s.index("world");
    ridx: int = s.rindex("l");

    # Predicates
    sw: bool = s.startswith("hello");
    sw_off: bool = s.startswith("world", 6);
    ew: bool = s.endswith("world");
    ew_off: bool = s.endswith("hello", 0, 5);

    # Replace
    rep: str = s.replace("world", "jac");
    rep_cnt: str = "abab".replace("ab", "X", 1);

    # Strip
    padded: str = "  hello  ";
    stripped: str = padded.strip();
    lstripped: str = padded.lstrip();
    rstripped: str = padded.rstrip();
    char_strip: str = "xxhelloxx".strip("x");

    # Prefix/suffix removal
    no_pre: str = "test_file.py".removeprefix("test_");
    no_suf: str = "test_file.py".removesuffix(".py");
    no_pre_miss: str = "test_file.py".removeprefix("foo_");

    # Split
    parts: list = s.split(" ");
    parts_max: list = "a.b.c.d".split(".", 2);
    rparts: list = "a.b.c.d".rsplit(".", 2);

    # Partition
    part = s.partition(" ");
    part_list: list = [part[0], part[1], part[2]];
    rpart = s.rpartition(" ");
    rpart_list: list = [rpart[0], rpart[1], rpart[2]];

    # Format
    fmt: str = "Hello {}!".format("Jac");
    fmt_idx: str = "{0} + {1} = {0}{1}".format("a", "b");

    # Alignment
    centered: str = "hi".center(10, "-");
    zfilled: str = "42".zfill(5);
    zfilled_neg: str = "-42".zfill(6);

    # Character tests
    is_num: bool = "123".isnumeric();
    not_num: bool = "12.3".isnumeric();
    is_ttl: bool = "Hello World".istitle();
    not_ttl: bool = "hello world".istitle();

    return {
        "capitalize": cap, "title": ttl, "swapcase": swp,
        "count": cnt, "count_range": cnt_range,
        "find": fnd, "find_miss": fnd_miss, "rfind": rfnd,
        "index": idx, "rindex": ridx,
        "startswith": sw, "startswith_off": sw_off,
        "endswith": ew, "endswith_off": ew_off,
        "replace": rep, "replace_count": rep_cnt,
        "strip": stripped, "lstrip": lstripped, "rstrip": rstripped,
        "char_strip": char_strip,
        "removeprefix": no_pre, "removesuffix": no_suf,
        "removeprefix_miss": no_pre_miss,
        "split": parts, "split_max": parts_max,
        "rsplit": rparts,
        "partition": part_list, "rpartition": rpart_list,
        "format": fmt, "format_idx": fmt_idx,
        "center": centered, "zfill": zfilled, "zfill_neg": zfilled_neg,
        "isnumeric": is_num, "isnumeric_false": not_num,
        "istitle": is_ttl, "istitle_false": not_ttl
    };
}

cl def jac_rt_str_cl() -> dict {
    s: str = "hello world";

    cap: str = s.capitalize();
    ttl: str = s.title();
    swp: str = "Hello World".swapcase();

    cnt: int = s.count("l");
    cnt_range: int = s.count("l", 0, 5);
    fnd: int = s.find("world");
    fnd_miss: int = s.find("xyz");
    rfnd: int = s.rfind("l");
    idx: int = s.index("world");
    ridx: int = s.rindex("l");

    sw: bool = s.startswith("hello");
    sw_off: bool = s.startswith("world", 6);
    ew: bool = s.endswith("world");
    ew_off: bool = s.endswith("hello", 0, 5);

    rep: str = s.replace("world", "jac");
    rep_cnt: str = "abab".replace("ab", "X", 1);

    padded: str = "  hello  ";
    stripped: str = padded.strip();
    lstripped: str = padded.lstrip();
    rstripped: str = padded.rstrip();
    char_strip: str = "xxhelloxx".strip("x");

    no_pre: str = "test_file.py".removeprefix("test_");
    no_suf: str = "test_file.py".removesuffix(".py");
    no_pre_miss: str = "test_file.py".removeprefix("foo_");

    parts: list = s.split(" ");
    parts_max: list = "a.b.c.d".split(".", 2);
    rparts: list = "a.b.c.d".rsplit(".", 2);
    lines: list = "a\nb\nc".splitlines();

    part = s.partition(" ");
    part_list: list = [part[0], part[1], part[2]];
    rpart = s.rpartition(" ");
    rpart_list: list = [rpart[0], rpart[1], rpart[2]];

    fmt: str = "Hello {}!".format("Jac");
    fmt_idx: str = "{0} + {1} = {0}{1}".format("a", "b");

    centered: str = "hi".center(10, "-");
    zfilled: str = "42".zfill(5);
    zfilled_neg: str = "-42".zfill(6);

    is_num: bool = "123".isnumeric();
    not_num: bool = "12.3".isnumeric();
    is_ttl: bool = "Hello World".istitle();
    not_ttl: bool = "hello world".istitle();

    return {
        "capitalize": cap, "title": ttl, "swapcase": swp,
        "count": cnt, "count_range": cnt_range,
        "find": fnd, "find_miss": fnd_miss, "rfind": rfnd,
        "index": idx, "rindex": ridx,
        "startswith": sw, "startswith_off": sw_off,
        "endswith": ew, "endswith_off": ew_off,
        "replace": rep, "replace_count": rep_cnt,
        "strip": stripped, "lstrip": lstripped, "rstrip": rstripped,
        "char_strip": char_strip,
        "removeprefix": no_pre, "removesuffix": no_suf,
        "removeprefix_miss": no_pre_miss,
        "split": parts, "split_max": parts_max,
        "rsplit": rparts,
        "partition": part_list, "rpartition": rpart_list,
        "format": fmt, "format_idx": fmt_idx,
        "center": centered, "zfill": zfilled, "zfill_neg": zfilled_neg,
        "isnumeric": is_num, "isnumeric_false": not_num,
        "istitle": is_ttl, "istitle_false": not_ttl
    };
}

# =============================================================================
# list namespace: sort, count, remove, index, repeat, comparisons, imul
# =============================================================================

def jac_rt_list_py() -> dict {
    # sort with key
    nums: list = [3, 1, 4, 1, 5, 9, 2, 6];
    nums.sort(key=lambda x: -x);

    # count
    items: list = [1, 2, 2, 3, 3, 3];
    cnt_2: int = items.count(2);
    cnt_3: int = items.count(3);
    cnt_0: int = items.count(99);

    # remove
    removable: list = [10, 20, 30, 20];
    removable.remove(20);

    # index
    idx: int = items.index(3);
    idx_start: int = items.index(3, 4);

    # repeat via *
    base: list = [1, 2];
    repeated: list = base * 3;

    # comparisons
    a: list = [1, 2, 3];
    b: list = [1, 2, 3];
    c: list = [1, 2, 4];
    d: list = [1, 2];
    eq_t: bool = a == b;
    eq_f: bool = a == c;
    lt_t: bool = a < c;
    lt_f: bool = c < a;
    gt_t: bool = c > a;
    le_t: bool = a <= b;
    le_t2: bool = a <= c;
    ge_t: bool = c >= a;
    lt_len: bool = d < a;

    # imul
    grow: list = [1, 2];
    grow *= 3;

    return {
        "sort_desc": nums,
        "count_2": cnt_2, "count_3": cnt_3, "count_miss": cnt_0,
        "after_remove": removable,
        "index": idx, "index_start": idx_start,
        "repeat": repeated,
        "eq_true": eq_t, "eq_false": eq_f,
        "lt_true": lt_t, "lt_false": lt_f, "gt_true": gt_t,
        "le_true": le_t, "le_true2": le_t2, "ge_true": ge_t,
        "lt_shorter": lt_len,
        "imul": grow
    };
}

cl def jac_rt_list_cl() -> dict {
    nums: list = [3, 1, 4, 1, 5, 9, 2, 6];
    nums.sort(key=lambda x: -x);

    items: list = [1, 2, 2, 3, 3, 3];
    cnt_2: int = items.count(2);
    cnt_3: int = items.count(3);
    cnt_0: int = items.count(99);

    removable: list = [10, 20, 30, 20];
    removable.remove(20);

    idx: int = items.index(3);
    idx_start: int = items.index(3, 4);

    base: list = [1, 2];
    repeated: list = base * 3;

    a: list = [1, 2, 3];
    b: list = [1, 2, 3];
    c: list = [1, 2, 4];
    d: list = [1, 2];
    eq_t: bool = a == b;
    eq_f: bool = a == c;
    lt_t: bool = a < c;
    lt_f: bool = c < a;
    gt_t: bool = c > a;
    le_t: bool = a <= b;
    le_t2: bool = a <= c;
    ge_t: bool = c >= a;
    lt_len: bool = d < a;

    grow: list = [1, 2];
    grow *= 3;

    return {
        "sort_desc": nums,
        "count_2": cnt_2, "count_3": cnt_3, "count_miss": cnt_0,
        "after_remove": removable,
        "index": idx, "index_start": idx_start,
        "repeat": repeated,
        "eq_true": eq_t, "eq_false": eq_f,
        "lt_true": lt_t, "lt_false": lt_f, "gt_true": gt_t,
        "le_true": le_t, "le_true2": le_t2, "ge_true": ge_t,
        "lt_shorter": lt_len,
        "imul": grow
    };
}

# =============================================================================
# dict namespace: pop, popitem, setdefault, clear, fromkeys, eq
# =============================================================================

def jac_rt_dict_py() -> dict {
    # pop
    d: dict = {"a": 1, "b": 2, "c": 3};
    popped: int = d.pop("b");
    pop_default: int = d.pop("z", -1);

    # popitem (LIFO — removes last inserted key)
    d2: dict = {"x": 10, "y": 20, "z": 30};
    item = d2.popitem();
    popitem_key: str = item[0];
    popitem_val: int = item[1];

    # setdefault
    d3: dict = {"a": 1};
    sd_existing: int = d3.setdefault("a", 99);
    sd_new = d3.setdefault("b", 42);

    # clear
    d4: dict = {"x": 1, "y": 2};
    d4.clear();

    # eq
    da: dict = {"a": 1, "b": 2};
    db: dict = {"b": 2, "a": 1};
    dc: dict = {"a": 1, "b": 3};
    eq_t: bool = da == db;
    eq_f: bool = da == dc;

    return {
        "pop_val": popped, "pop_default": pop_default,
        "after_pop": d,
        "popitem_key": popitem_key, "popitem_val": popitem_val,
        "sd_existing": sd_existing, "sd_new": sd_new,
        "after_setdefault": d3,
        "after_clear": d4,
        "eq_true": eq_t, "eq_false": eq_f
    };
}

cl def jac_rt_dict_cl() -> dict {
    d: dict = {"a": 1, "b": 2, "c": 3};
    popped: int = d.pop("b");
    pop_default: int = d.pop("z", -1);

    d2: dict = {"x": 10, "y": 20, "z": 30};
    item = d2.popitem();
    popitem_key: str = item[0];
    popitem_val: int = item[1];

    d3: dict = {"a": 1};
    sd_existing: int = d3.setdefault("a", 99);
    sd_new = d3.setdefault("b", 42);

    d4: dict = {"x": 1, "y": 2};
    d4.clear();

    da: dict = {"a": 1, "b": 2};
    db: dict = {"b": 2, "a": 1};
    dc: dict = {"a": 1, "b": 3};
    eq_t: bool = da == db;
    eq_f: bool = da == dc;

    return {
        "pop_val": popped, "pop_default": pop_default,
        "after_pop": d,
        "popitem_key": popitem_key, "popitem_val": popitem_val,
        "sd_existing": sd_existing, "sd_new": sd_new,
        "after_setdefault": d3,
        "after_clear": d4,
        "eq_true": eq_t, "eq_false": eq_f
    };
}

# =============================================================================
# set namespace: remove, update, intersection_update, difference_update,
#   symmetric_difference_update, is_proper_subset, is_proper_superset, eq
# (pop skipped — non-deterministic ordering)
# (results converted to sorted lists for JSON serialization)
# =============================================================================

def jac_rt_set_py() -> dict {
    # remove
    s1: set = {1, 2, 3, 4};
    s1.remove(3);
    after_remove: list = sorted(list(s1));

    # update
    s2: set = {1, 2};
    s2.update({3, 4});
    after_update: list = sorted(list(s2));

    # intersection_update
    s3: set = {1, 2, 3, 4};
    s3.intersection_update({2, 4, 6});
    after_isect: list = sorted(list(s3));

    # difference_update
    s4: set = {1, 2, 3, 4};
    s4.difference_update({2, 4});
    after_diff: list = sorted(list(s4));

    # symmetric_difference_update
    s5: set = {1, 2, 3};
    s5.symmetric_difference_update({2, 3, 4});
    after_symdiff: list = sorted(list(s5));

    # subset/superset
    small: set = {1, 2};
    big: set = {1, 2, 3};
    same: set = {1, 2};
    proper_sub: bool = small < big;
    not_proper_sub: bool = small < same;
    proper_sup: bool = big > small;
    eq_t: bool = small == same;
    eq_f: bool = small == big;

    return {
        "after_remove": after_remove,
        "after_update": after_update,
        "after_isect": after_isect,
        "after_diff": after_diff,
        "after_symdiff": after_symdiff,
        "proper_subset": proper_sub,
        "not_proper_subset": not_proper_sub,
        "proper_superset": proper_sup,
        "eq_true": eq_t, "eq_false": eq_f
    };
}

cl def jac_rt_set_cl() -> dict {
    s1: set = {1, 2, 3, 4};
    s1.remove(3);
    after_remove: list = sorted(list(s1));

    s2: set = {1, 2};
    s2.update({3, 4});
    after_update: list = sorted(list(s2));

    s3: set = {1, 2, 3, 4};
    s3.intersection_update({2, 4, 6});
    after_isect: list = sorted(list(s3));

    s4: set = {1, 2, 3, 4};
    s4.difference_update({2, 4});
    after_diff: list = sorted(list(s4));

    s5: set = {1, 2, 3};
    s5.symmetric_difference_update({2, 3, 4});
    after_symdiff: list = sorted(list(s5));

    small: set = {1, 2};
    big: set = {1, 2, 3};
    same: set = {1, 2};
    proper_sub: bool = small < big;
    not_proper_sub: bool = small < same;
    proper_sup: bool = big > small;
    eq_t: bool = small == same;
    eq_f: bool = small == big;

    return {
        "after_remove": after_remove,
        "after_update": after_update,
        "after_isect": after_isect,
        "after_diff": after_diff,
        "after_symdiff": after_symdiff,
        "proper_subset": proper_sub,
        "not_proper_subset": not_proper_sub,
        "proper_superset": proper_sup,
        "eq_true": eq_t, "eq_false": eq_f
    };
}

# =============================================================================
# tuple namespace: count, index, repeat, comparisons
# =============================================================================

def jac_rt_tuple_py() -> dict {
    t: tuple = (1, 2, 3, 2, 1);

    # count / index
    cnt: int = t.count(2);
    idx: int = t.index(3);

    # repeat via *
    t2: tuple = (1, 2);
    repeated: list = list(t2 * 3);

    # comparisons
    a: tuple = (1, 2, 3);
    b: tuple = (1, 2, 3);
    c: tuple = (1, 2, 4);
    d: tuple = (1, 2);
    eq_t: bool = a == b;
    eq_f: bool = a == c;
    lt_t: bool = a < c;
    gt_t: bool = c > a;
    le_t: bool = a <= b;
    ge_t: bool = c >= a;
    lt_len: bool = d < a;

    return {
        "count": cnt, "index": idx,
        "repeat": repeated,
        "eq_true": eq_t, "eq_false": eq_f,
        "lt_true": lt_t, "gt_true": gt_t,
        "le_true": le_t, "ge_true": ge_t,
        "lt_shorter": lt_len
    };
}

cl def jac_rt_tuple_cl() -> dict {
    t: tuple = (1, 2, 3, 2, 1);

    cnt: int = t.count(2);
    idx: int = t.index(3);

    t2: tuple = (1, 2);
    repeated: list = list(t2 * 3);

    a: tuple = (1, 2, 3);
    b: tuple = (1, 2, 3);
    c: tuple = (1, 2, 4);
    d: tuple = (1, 2);
    eq_t: bool = a == b;
    eq_f: bool = a == c;
    lt_t: bool = a < c;
    gt_t: bool = c > a;
    le_t: bool = a <= b;
    ge_t: bool = c >= a;
    lt_len: bool = d < a;

    return {
        "count": cnt, "index": idx,
        "repeat": repeated,
        "eq_true": eq_t, "eq_false": eq_f,
        "lt_true": lt_t, "gt_true": gt_t,
        "le_true": le_t, "ge_true": ge_t,
        "lt_shorter": lt_len
    };
}

# =============================================================================
# builtin namespace: round, sum, sorted, enumerate, zip, map, filter, pow
# (hash/repr/id skipped — implementations intentionally differ)
# (ascii skipped — quoting style differs)
# (vars/dir/open/issubclass/next/complex skipped — not cross-backend testable)
# =============================================================================

def jac_rt_builtin_py() -> dict {
    # round
    r1: int = round(3.7);
    r2: float = round(3.14159, 2);

    # sum
    s: int = sum([1, 2, 3, 4, 5]);
    s_start: int = sum([1, 2, 3], 10);

    # sorted (basic, reverse, key)
    srt: list = sorted([3, 1, 4, 1, 5]);
    srt_key: list = sorted(["banana", "apple", "kiwi"], key=lambda x: len(x));

    # enumerate — use loop to convert tuples to lists
    raw_enum: list = list(enumerate(["a", "b", "c"]));
    enum_result: list = [];
    for pair in raw_enum {
        enum_result.append([pair[0], pair[1]]);
    }
    raw_enum2: list = list(enumerate(["x", "y"], 5));
    enum_start: list = [];
    for pair in raw_enum2 {
        enum_start.append([pair[0], pair[1]]);
    }

    # zip — use loop to convert tuples to lists
    raw_zip: list = list(zip([1, 2, 3], ["a", "b", "c"]));
    zip_result: list = [];
    for pair in raw_zip {
        zip_result.append([pair[0], pair[1]]);
    }
    raw_zip2: list = list(zip([1, 2], ["a", "b", "c"]));
    zip_uneven: list = [];
    for pair in raw_zip2 {
        zip_uneven.append([pair[0], pair[1]]);
    }

    # map
    map_result: list = list(map(lambda x: x * 2, [1, 2, 3, 4]));

    # filter
    filter_result: list = list(filter(lambda x: x > 2, [1, 2, 3, 4, 5]));

    # pow
    pow_basic: int = pow(2, 10);
    pow_mod: int = pow(2, 10, 100);

    return {
        "round_int": r1, "round_digits": r2,
        "sum": s, "sum_start": s_start,
        "sorted": srt, "sorted_key": srt_key,
        "enumerate": enum_result, "enumerate_start": enum_start,
        "zip": zip_result, "zip_uneven": zip_uneven,
        "map": map_result,
        "filter": filter_result,
        "pow": pow_basic, "pow_mod": pow_mod
    };
}

cl def jac_rt_builtin_cl() -> dict {
    r1: int = round(3.7);
    r2: float = round(3.14159, 2);

    s: int = sum([1, 2, 3, 4, 5]);
    s_start: int = sum([1, 2, 3], 10);

    srt: list = sorted([3, 1, 4, 1, 5]);
    srt_key: list = sorted(["banana", "apple", "kiwi"], key=lambda x: len(x));

    raw_enum: list = list(enumerate(["a", "b", "c"]));
    enum_result: list = [];
    for pair in raw_enum {
        enum_result.append([pair[0], pair[1]]);
    }
    raw_enum2: list = list(enumerate(["x", "y"], 5));
    enum_start: list = [];
    for pair in raw_enum2 {
        enum_start.append([pair[0], pair[1]]);
    }

    raw_zip: list = list(zip([1, 2, 3], ["a", "b", "c"]));
    zip_result: list = [];
    for pair in raw_zip {
        zip_result.append([pair[0], pair[1]]);
    }
    raw_zip2: list = list(zip([1, 2], ["a", "b", "c"]));
    zip_uneven: list = [];
    for pair in raw_zip2 {
        zip_uneven.append([pair[0], pair[1]]);
    }

    map_result: list = list(map(lambda x: x * 2, [1, 2, 3, 4]));

    filter_result: list = list(filter(lambda x: x > 2, [1, 2, 3, 4, 5]));

    pow_basic: int = pow(2, 10);
    pow_mod: int = pow(2, 10, 100);

    return {
        "round_int": r1, "round_digits": r2,
        "sum": s, "sum_start": s_start,
        "sorted": srt, "sorted_key": srt_key,
        "enumerate": enum_result, "enumerate_start": enum_start,
        "zip": zip_result, "zip_uneven": zip_uneven,
        "map": map_result,
        "filter": filter_result,
        "pow": pow_basic, "pow_mod": pow_mod
    };
}
