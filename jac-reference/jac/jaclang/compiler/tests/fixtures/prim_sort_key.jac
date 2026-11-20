"""sorted()/sort() with key= callables, including str-returning keys.

Cross-backend equivalence fixture. The native lane guards the sort
comparator delegation in NativeListEmitter.emit_sort: key results are
compared through the canonical operator comparison path
(NaIRGenPass._emit_comparison), which handles str descriptors with
length-aware, NUL-safe comparison (#9144).

The aggregate rows pin per-element semantics inside tuple/list keys:
float elements order numerically (Jac float lowers to f64, f32 stays
f32), unsigned elements (u8-u64) order unsigned above 2^63 from the
key's semantic type args, str elements compare through the string
comparator, and an empty list key keeps the input order (stable sort).
"""
def u64_key(w: str) -> u64 {
    # len * 2^61 straddles 2^63 (len 3 below, len 4/5 above), so a signed
    # comparator moves the shortest word to the front (#9144).
    return u64(len(w)) * u64(2305843009213693952);
}

def u64_pair_key(w: str) -> (u64, int) {
    # Named aggregate key: the u64 element must still order unsigned.
    return (u64(len(w)) * u64(2305843009213693952), len(w));
}

def sort_key_py -> dict[str, any] {
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
    by_ftup: list[int] = sorted(
        agg, key=lambda (x: int) -> (float, int) { (10.5 - x, x); }
    );
    by_flist: list[int] = sorted(
        agg, key=lambda (x: int) -> list[float] { [x * 1.0, 0.0]; }
    );
    by_f32: list[int] = sorted(agg, key=lambda (x: int) -> f32 { f32(3 - x); });
    by_mixf: list[int] = sorted(
        agg, key=lambda (x: int) -> (int, float) { (0, x * 1.5); }
    );
    by_emp: list[int] = sorted(agg, key=lambda (x: int) -> list[int] { []; });
    by_sint: list[str] = sorted(
        words, key=lambda (w: str) -> (str, int) { (w[0:1], len(w)); }
    );
    by_u64t: list[str] = sorted(
        words,
        key=lambda (w: str) -> (u64, int) { (
            u64(len(w)) * u64(2305843009213693952),
            len(w)
        ); }
    );
    by_u64t_rev: list[str] = sorted(
        words,
        key=lambda (w: str) -> (u64, int) { (
            u64(len(w)) * u64(2305843009213693952),
            len(w)
        ); },
        reverse=True
    );
    by_u64l: list[str] = sorted(
        words,
        key=lambda (w: str) -> list[u64] { [u64(len(w)) * u64(2305843009213693952)]; }
    );
    by_unest: list[str] = sorted(
        words,
        key=lambda (w: str) -> (list[u64], int) { (
            [u64(len(w)) * u64(2305843009213693952)],
            len(w)
        ); }
    );
    by_ntup: list[str] = sorted(words, key=u64_pair_key);
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
        "ft0": by_ftup[0],
        "ft2": by_ftup[2],
        "fl0": by_flist[0],
        "fl2": by_flist[2],
        "ff0": by_f32[0],
        "ff2": by_f32[2],
        "mf0": by_mixf[0],
        "mf2": by_mixf[2],
        "em0": by_emp[0],
        "em2": by_emp[2],
        "sk0": by_sint[0],
        "sk3": by_sint[3],
        "ut0": by_u64t[0],
        "ut3": by_u64t[3],
        "utr0": by_u64t_rev[0],
        "ul0": by_u64l[0],
        "ul3": by_u64l[3],
        "un0": by_unest[0],
        "un3": by_unest[3],
        "nt0": by_ntup[0],
        "nt3": by_ntup[3],
        "nk0": sorted(words, key=u64_key)[0],
        "nk3": sorted(words, key=u64_key)[3],
        "nkr0": sorted(words, key=u64_key, reverse=True)[0]
    };
}

def sort_key_cl -> dict[str, any] {
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
    by_ftup: list[int] = sorted(
        agg, key=lambda (x: int) -> (float, int) { (10.5 - x, x); }
    );
    by_flist: list[int] = sorted(
        agg, key=lambda (x: int) -> list[float] { [x * 1.0, 0.0]; }
    );
    by_f32: list[int] = sorted(agg, key=lambda (x: int) -> f32 { f32(3 - x); });
    by_mixf: list[int] = sorted(
        agg, key=lambda (x: int) -> (int, float) { (0, x * 1.5); }
    );
    by_emp: list[int] = sorted(agg, key=lambda (x: int) -> list[int] { []; });
    by_sint: list[str] = sorted(
        words, key=lambda (w: str) -> (str, int) { (w[0:1], len(w)); }
    );
    by_u64t: list[str] = sorted(
        words,
        key=lambda (w: str) -> (u64, int) { (
            u64(len(w)) * u64(2305843009213693952),
            len(w)
        ); }
    );
    by_u64t_rev: list[str] = sorted(
        words,
        key=lambda (w: str) -> (u64, int) { (
            u64(len(w)) * u64(2305843009213693952),
            len(w)
        ); },
        reverse=True
    );
    by_u64l: list[str] = sorted(
        words,
        key=lambda (w: str) -> list[u64] { [u64(len(w)) * u64(2305843009213693952)]; }
    );
    by_unest: list[str] = sorted(
        words,
        key=lambda (w: str) -> (list[u64], int) { (
            [u64(len(w)) * u64(2305843009213693952)],
            len(w)
        ); }
    );
    by_ntup: list[str] = sorted(words, key=u64_pair_key);
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
        "ft0": by_ftup[0],
        "ft2": by_ftup[2],
        "fl0": by_flist[0],
        "fl2": by_flist[2],
        "ff0": by_f32[0],
        "ff2": by_f32[2],
        "mf0": by_mixf[0],
        "mf2": by_mixf[2],
        "em0": by_emp[0],
        "em2": by_emp[2],
        "sk0": by_sint[0],
        "sk3": by_sint[3],
        "ut0": by_u64t[0],
        "ut3": by_u64t[3],
        "utr0": by_u64t_rev[0],
        "ul0": by_u64l[0],
        "ul3": by_u64l[3],
        "un0": by_unest[0],
        "un3": by_unest[3],
        "nt0": by_ntup[0],
        "nt3": by_ntup[3],
        "nk0": sorted(words, key=u64_key)[0],
        "nk3": sorted(words, key=u64_key)[3],
        "nkr0": sorted(words, key=u64_key, reverse=True)[0]
    };
}

def sort_key_na -> dict[str, any] {
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
    by_ftup: list[int] = sorted(
        agg, key=lambda (x: int) -> (float, int) { (10.5 - x, x); }
    );
    by_flist: list[int] = sorted(
        agg, key=lambda (x: int) -> list[float] { [x * 1.0, 0.0]; }
    );
    by_f32: list[int] = sorted(agg, key=lambda (x: int) -> f32 { f32(3 - x); });
    by_mixf: list[int] = sorted(
        agg, key=lambda (x: int) -> (int, float) { (0, x * 1.5); }
    );
    by_emp: list[int] = sorted(agg, key=lambda (x: int) -> list[int] { []; });
    by_sint: list[str] = sorted(
        words, key=lambda (w: str) -> (str, int) { (w[0:1], len(w)); }
    );
    by_u64t: list[str] = sorted(
        words,
        key=lambda (w: str) -> (u64, int) { (
            u64(len(w)) * u64(2305843009213693952),
            len(w)
        ); }
    );
    by_u64t_rev: list[str] = sorted(
        words,
        key=lambda (w: str) -> (u64, int) { (
            u64(len(w)) * u64(2305843009213693952),
            len(w)
        ); },
        reverse=True
    );
    by_u64l: list[str] = sorted(
        words,
        key=lambda (w: str) -> list[u64] { [u64(len(w)) * u64(2305843009213693952)]; }
    );
    by_unest: list[str] = sorted(
        words,
        key=lambda (w: str) -> (list[u64], int) { (
            [u64(len(w)) * u64(2305843009213693952)],
            len(w)
        ); }
    );
    by_ntup: list[str] = sorted(words, key=u64_pair_key);
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
        "ft0": by_ftup[0],
        "ft2": by_ftup[2],
        "fl0": by_flist[0],
        "fl2": by_flist[2],
        "ff0": by_f32[0],
        "ff2": by_f32[2],
        "mf0": by_mixf[0],
        "mf2": by_mixf[2],
        "em0": by_emp[0],
        "em2": by_emp[2],
        "sk0": by_sint[0],
        "sk3": by_sint[3],
        "ut0": by_u64t[0],
        "ut3": by_u64t[3],
        "utr0": by_u64t_rev[0],
        "ul0": by_u64l[0],
        "ul3": by_u64l[3],
        "un0": by_unest[0],
        "un3": by_unest[3],
        "nt0": by_ntup[0],
        "nt3": by_ntup[3],
        "nk0": sorted(words, key=u64_key)[0],
        "nk3": sorted(words, key=u64_key)[3],
        "nkr0": sorted(words, key=u64_key, reverse=True)[0]
    };
}
