"""Cross-backend structural match pattern equivalence (#7593 item 7).

Sequence, star, mapping, and class (MatchArch) patterns must produce
CPython-identical results on the native backend. The py defs are the
Python reference; both sides cast captures `(x as T)` because match
captures type as Unknown in the checker and na-block modules run the
strict native type schedule over the whole module. No cl defs: the
ecmascript passes have no MatchStmt lowering, so the cl leg auto-skips
(precedent: native_list_any_ops.jac).

The `collections` import below is a deliberate server signal: it keeps
the module out of whole-module native inference so the py defs stay a
genuine CPython reference instead of coercing to native shims."""

import collections;

obj MatchPt {
    has x: int,
        y: int;
}

obj MatchBase {
    has tag: int;
}

obj MatchSub(MatchBase) {
    has extra: int;
}

def _seq_fixed_ref(a: int, b: int) -> int {
    xs: list[int] = [a, b];
    match xs {
        case [1, 2]: return 1;
        case [x, y]: return (x as int) + (y as int);
        case _: return 0;
    }
}

def _seq_len_ref(n: int) -> int {
    xs: list[int] = [];
    for i in range(n) {
        xs.append(i);
    }
    match xs {
        case []: return 0;
        case [a]: return 1;
        case [a, b]: return 2;
        case _: return -1;
    }
}

def _nested_ref(k: int) -> int {
    xss: list[list[int]] = [[1, 2], [3]];
    if k == 1 {
        xss = [[1, 2], [3, 4]];
    }
    match xss {
        case [[a, b], [c]]: return (a as int) + (b as int) + (c as int);
        case _: return -1;
    }
}

def _seq_guard_ref(a: int, b: int) -> int {
    xs: list[int] = [a, b];
    match xs {
        case [x, y] if (x as int) > (y as int): return 1;
        case [x, y]: return 2;
        case _: return 3;
    }
}

def match_seq_py() -> dict {
    return {
        "fixed12": _seq_fixed_ref(1, 2),
        "fixed34": _seq_fixed_ref(3, 4),
        "len0": _seq_len_ref(0),
        "len1": _seq_len_ref(1),
        "len2": _seq_len_ref(2),
        "len5": _seq_len_ref(5),
        "nested_hit": _nested_ref(0),
        "nested_miss": _nested_ref(1),
        "guard_gt": _seq_guard_ref(5, 1),
        "guard_le": _seq_guard_ref(1, 5)
    };
}

def _star_head_ref(n: int) -> int {
    xs: list[int] = [];
    for i in range(n) {
        xs.append(i + 10);
    }
    match xs {
        case [first, *rest]: return (first as int) * 100 + len(
            (rest as list[int])
        );
        case _: return -1;
    }
}

def _star_tail_ref(n: int) -> int {
    xs: list[int] = [];
    for i in range(n) {
        xs.append(i + 10);
    }
    match xs {
        case [*front, last]: return (last as int) * 100 + len(
            (front as list[int])
        );
        case _: return -1;
    }
}

def _star_mid_ref(n: int) -> int {
    xs: list[int] = [];
    for i in range(n) {
        xs.append(i + 10);
    }
    match xs {
        case [first, *mid, last]: return (first as int) + (last as int) * 100
            + len((mid as list[int]));
        case _: return -1;
    }
}

def match_star_py() -> dict {
    return {
        "head0": _star_head_ref(0),
        "head1": _star_head_ref(1),
        "head3": _star_head_ref(3),
        "tail1": _star_tail_ref(1),
        "tail3": _star_tail_ref(3),
        "mid1": _star_mid_ref(1),
        "mid2": _star_mid_ref(2),
        "mid4": _star_mid_ref(4)
    };
}

def _map_probe_ref(k: int) -> int {
    d: dict[str, int] = {"a": 1, "b": 2};
    match d {
        case {"a": v} if k == 0: return (v as int);
        case {"a": v, "b": w}: return (v as int) + (w as int);
        case _: return -1;
    }
}

def _map_missing_ref() -> int {
    d: dict[str, int] = {"a": 1, "b": 2};
    match d {
        case {"z": v}: return 1;
        case _: return -1;
    }
}

def _map_rest_ref() -> int {
    d: dict[str, int] = {"a": 1, "b": 2, "c": 3};
    match d {
        case {"a": v, **rest}: return (v as int) * 100 + len(
            (rest as dict[str, int])
        );
        case _: return -1;
    }
}

def match_map_py() -> dict {
    return {
        "probe_guard": _map_probe_ref(0),
        "probe_both": _map_probe_ref(1),
        "miss": _map_missing_ref(),
        "rest": _map_rest_ref()
    };
}

def _arch_kw_ref(px: int, py2: int) -> int {
    p = MatchPt(x=px, y=py2);
    match p {
        case MatchPt(x=a, y=b): return (a as int) * 10 + (b as int);
        case _: return -1;
    }
}

def _arch_pos_ref(px: int, py2: int) -> int {
    p = MatchPt(x=px, y=py2);
    match p {
        case MatchPt(a, b): return (a as int) * 10 + (b as int);
        case _: return -1;
    }
}

def _arch_sub_ref(sel: int) -> int {
    o: MatchBase = MatchBase(tag=7);
    if sel == 1 {
        o = MatchSub(tag=7, extra=9);
    }
    match o {
        case MatchSub(extra=e): return (e as int);
        case MatchBase(tag=t): return (t as int);
        case _: return -1;
    }
}

def match_arch_py() -> dict {
    return {
        "kw": _arch_kw_ref(3, 4),
        "pos": _arch_pos_ref(5, 6),
        "sub": _arch_sub_ref(1),
        "base": _arch_sub_ref(0)
    };
}

na {
    def _seq_fixed_na_i(a: int, b: int) -> int {
        xs: list[int] = [a, b];
        match xs {
            case [1, 2]: return 1;
            case [x, y]: return (x as int) + (y as int);
            case _: return 0;
        }
    }

    def _seq_len_na_i(n: int) -> int {
        xs: list[int] = [];
        for i in range(n) {
            xs.append(i);
        }
        match xs {
            case []: return 0;
            case [a]: return 1;
            case [a, b]: return 2;
            case _: return -1;
        }
    }

    def _nested_na_i(k: int) -> int {
        xss: list[list[int]] = [[1, 2], [3]];
        if k == 1 {
            xss = [[1, 2], [3, 4]];
        }
        match xss {
            case [[a, b], [c]]: return (a as int) + (b as int) + (c as int);
            case _: return -1;
        }
    }

    def _seq_guard_na_i(a: int, b: int) -> int {
        xs: list[int] = [a, b];
        match xs {
            case [x, y] if (x as int) > (y as int): return 1;
            case [x, y]: return 2;
            case _: return 3;
        }
    }

    def match_seq_na() -> dict[str, any] {
        return {
            "fixed12": _seq_fixed_na_i(1, 2),
            "fixed34": _seq_fixed_na_i(3, 4),
            "len0": _seq_len_na_i(0),
            "len1": _seq_len_na_i(1),
            "len2": _seq_len_na_i(2),
            "len5": _seq_len_na_i(5),
            "nested_hit": _nested_na_i(0),
            "nested_miss": _nested_na_i(1),
            "guard_gt": _seq_guard_na_i(5, 1),
            "guard_le": _seq_guard_na_i(1, 5)
        };
    }

    def _star_head_na_i(n: int) -> int {
        xs: list[int] = [];
        for i in range(n) {
            xs.append(i + 10);
        }
        match xs {
            case [first, *rest]: return (first as int) * 100 + len(
                (rest as list[int])
            );
            case _: return -1;
        }
    }

    def _star_tail_na_i(n: int) -> int {
        xs: list[int] = [];
        for i in range(n) {
            xs.append(i + 10);
        }
        match xs {
            case [*front, last]: return (last as int) * 100 + len(
                (front as list[int])
            );
            case _: return -1;
        }
    }

    def _star_mid_na_i(n: int) -> int {
        xs: list[int] = [];
        for i in range(n) {
            xs.append(i + 10);
        }
        match xs {
            case [first, *mid, last]: return (first as int) + (last as int) * 100
                + len((mid as list[int]));
            case _: return -1;
        }
    }

    def match_star_na() -> dict[str, any] {
        return {
            "head0": _star_head_na_i(0),
            "head1": _star_head_na_i(1),
            "head3": _star_head_na_i(3),
            "tail1": _star_tail_na_i(1),
            "tail3": _star_tail_na_i(3),
            "mid1": _star_mid_na_i(1),
            "mid2": _star_mid_na_i(2),
            "mid4": _star_mid_na_i(4)
        };
    }

    def _map_probe_na_i(k: int) -> int {
        d: dict[str, int] = {"a": 1, "b": 2};
        match d {
            case {"a": v} if k == 0: return (v as int);
            case {"a": v, "b": w}: return (v as int) + (w as int);
            case _: return -1;
        }
    }

    def _map_missing_na_i() -> int {
        d: dict[str, int] = {"a": 1, "b": 2};
        match d {
            case {"z": v}: return 1;
            case _: return -1;
        }
    }

    def _map_rest_na_i() -> int {
        d: dict[str, int] = {"a": 1, "b": 2, "c": 3};
        match d {
            case {"a": v, **rest}: return (v as int) * 100 + len(
                (rest as dict[str, int])
            );
            case _: return -1;
        }
    }

    def match_map_na() -> dict[str, any] {
        return {
            "probe_guard": _map_probe_na_i(0),
            "probe_both": _map_probe_na_i(1),
            "miss": _map_missing_na_i(),
            "rest": _map_rest_na_i()
        };
    }

    def _arch_kw_na_i(px: int, py2: int) -> int {
        p = MatchPt(x=px, y=py2);
        match p {
            case MatchPt(x=a, y=b): return (a as int) * 10 + (b as int);
            case _: return -1;
        }
    }

    def _arch_pos_na_i(px: int, py2: int) -> int {
        p = MatchPt(x=px, y=py2);
        match p {
            case MatchPt(a, b): return (a as int) * 10 + (b as int);
            case _: return -1;
        }
    }

    def _arch_sub_na_i(sel: int) -> int {
        o: MatchBase = MatchBase(tag=7);
        if sel == 1 {
            o = MatchSub(tag=7, extra=9);
        }
        match o {
            case MatchSub(extra=e): return (e as int);
            case MatchBase(tag=t): return (t as int);
            case _: return -1;
        }
    }

    def match_arch_na() -> dict[str, any] {
        return {
            "kw": _arch_kw_na_i(3, 4),
            "pos": _arch_pos_na_i(5, 6),
            "sub": _arch_sub_na_i(1),
            "base": _arch_sub_na_i(0)
        };
    }
}
