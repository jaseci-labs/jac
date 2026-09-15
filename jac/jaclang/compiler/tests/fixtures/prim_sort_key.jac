"""sorted()/sort() with key= callables, including str-returning keys.

Cross-backend equivalence fixture. The native lane guards the sort
comparator delegation in NativeListEmitter.emit_sort: key results are
compared through the canonical operator comparison path
(NaIRGenPass._emit_comparison), which handles str descriptors with
length-aware, NUL-safe comparison (#9144).
"""
def u64_key(w: str) -> u64 {
    # len * 2^61 straddles 2^63 (len 3 below, len 4/5 above), so a signed
    # comparator moves the shortest word to the front (#9144).
    return u64(len(w)) * u64(2305843009213693952);
}


def sort_key_py -> dict {
    words: list[str] = ["pear", "fig", "apple", "kiwi"];
    by_str: list[str] = sorted(words, key=lambda (w: str) -> str { w; });
    by_rev: list[str] = sorted(words, key=lambda (w: str) -> str { w; }, reverse=True);
    by_sub: list[str] = sorted(words, key=lambda (w: str) -> str { w[0:2]; });
    nums: list[int] = [30, 10, 20];
    by_neg: list[int] = sorted(nums, key=lambda (x: int) -> int { -x; });
    agg: list[int] = [3, 1, 2];
    flags: list[bool] = [True, False, True];
    lut: list[int] = [0, 1];
    by_bool: list[int] = sorted(agg, key=lambda (x: int) -> bool { x > 1; });
    by_bool_rev: list[int] = sorted(
        agg, key=lambda (x: int) -> bool { x > 1; }, reverse=True
    );
    by_tup: list[int] = sorted(agg, key=lambda (x: int) -> (int, int) { (x, 0); });
    by_list: list[int] = sorted(agg, key=lambda (x: int) -> list[int] { [x, 0]; });
    by_btup: list[int] = sorted(
        agg, key=lambda (x: int) -> (bool, int) { (x > 1, x); }
    );
    plain_b: list[bool] = sorted(flags);
    in_place: list[str] = ["b2", "a9", "c1"];
    in_place.sort(key=lambda (w: str) -> str { w; });
    return {
        "asc0": by_str[0],
        "asc3": by_str[3],
        "desc0": by_rev[0],
        "desc3": by_rev[3],
        "sub0": by_sub[0],
        "sub3": by_sub[3],
        "neg0": by_neg[0],
        "neg2": by_neg[2],
        "ip0": in_place[0],
        "ip2": in_place[2],
        "basc0": by_bool[0],
        "brev0": by_bool_rev[0],
        "tup0": by_tup[0],
        "lasc0": by_list[0],
        "bt0": by_btup[0],
        "pk0": lut[plain_b[0]],
        "nk0": sorted(words, key=u64_key)[0],
        "nk3": sorted(words, key=u64_key)[3],
        "nkr0": sorted(words, key=u64_key, reverse=True)[0]
    };
}

def sort_key_cl -> dict {
    words: list[str] = ["pear", "fig", "apple", "kiwi"];
    by_str: list[str] = sorted(words, key=lambda (w: str) -> str { w; });
    by_rev: list[str] = sorted(words, key=lambda (w: str) -> str { w; }, reverse=True);
    by_sub: list[str] = sorted(words, key=lambda (w: str) -> str { w[0:2]; });
    nums: list[int] = [30, 10, 20];
    by_neg: list[int] = sorted(nums, key=lambda (x: int) -> int { -x; });
    agg: list[int] = [3, 1, 2];
    flags: list[bool] = [True, False, True];
    lut: list[int] = [0, 1];
    by_bool: list[int] = sorted(agg, key=lambda (x: int) -> bool { x > 1; });
    by_bool_rev: list[int] = sorted(
        agg, key=lambda (x: int) -> bool { x > 1; }, reverse=True
    );
    by_tup: list[int] = sorted(agg, key=lambda (x: int) -> (int, int) { (x, 0); });
    by_list: list[int] = sorted(agg, key=lambda (x: int) -> list[int] { [x, 0]; });
    by_btup: list[int] = sorted(
        agg, key=lambda (x: int) -> (bool, int) { (x > 1, x); }
    );
    plain_b: list[bool] = sorted(flags);
    in_place: list[str] = ["b2", "a9", "c1"];
    in_place.sort(key=lambda (w: str) -> str { w; });
    return {
        "asc0": by_str[0],
        "asc3": by_str[3],
        "desc0": by_rev[0],
        "desc3": by_rev[3],
        "sub0": by_sub[0],
        "sub3": by_sub[3],
        "neg0": by_neg[0],
        "neg2": by_neg[2],
        "ip0": in_place[0],
        "ip2": in_place[2],
        "basc0": by_bool[0],
        "brev0": by_bool_rev[0],
        "tup0": by_tup[0],
        "lasc0": by_list[0],
        "bt0": by_btup[0],
        "pk0": lut[plain_b[0]],
        "nk0": sorted(words, key=u64_key)[0],
        "nk3": sorted(words, key=u64_key)[3],
        "nkr0": sorted(words, key=u64_key, reverse=True)[0]
    };
}

def sort_key_na -> dict {
    words: list[str] = ["pear", "fig", "apple", "kiwi"];
    by_str: list[str] = sorted(words, key=lambda (w: str) -> str { w; });
    by_rev: list[str] = sorted(words, key=lambda (w: str) -> str { w; }, reverse=True);
    by_sub: list[str] = sorted(words, key=lambda (w: str) -> str { w[0:2]; });
    nums: list[int] = [30, 10, 20];
    by_neg: list[int] = sorted(nums, key=lambda (x: int) -> int { -x; });
    agg: list[int] = [3, 1, 2];
    flags: list[bool] = [True, False, True];
    lut: list[int] = [0, 1];
    by_bool: list[int] = sorted(agg, key=lambda (x: int) -> bool { x > 1; });
    by_bool_rev: list[int] = sorted(
        agg, key=lambda (x: int) -> bool { x > 1; }, reverse=True
    );
    by_tup: list[int] = sorted(agg, key=lambda (x: int) -> (int, int) { (x, 0); });
    by_list: list[int] = sorted(agg, key=lambda (x: int) -> list[int] { [x, 0]; });
    by_btup: list[int] = sorted(
        agg, key=lambda (x: int) -> (bool, int) { (x > 1, x); }
    );
    plain_b: list[bool] = sorted(flags);
    in_place: list[str] = ["b2", "a9", "c1"];
    in_place.sort(key=lambda (w: str) -> str { w; });
    return {
        "asc0": by_str[0],
        "asc3": by_str[3],
        "desc0": by_rev[0],
        "desc3": by_rev[3],
        "sub0": by_sub[0],
        "sub3": by_sub[3],
        "neg0": by_neg[0],
        "neg2": by_neg[2],
        "ip0": in_place[0],
        "ip2": in_place[2],
        "basc0": by_bool[0],
        "brev0": by_bool_rev[0],
        "tup0": by_tup[0],
        "lasc0": by_list[0],
        "bt0": by_btup[0],
        "pk0": lut[plain_b[0]],
        "nk0": sorted(words, key=u64_key)[0],
        "nk3": sorted(words, key=u64_key)[3],
        "nkr0": sorted(words, key=u64_key, reverse=True)[0]
    };
}
