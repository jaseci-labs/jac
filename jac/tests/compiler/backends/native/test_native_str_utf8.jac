"""UTF-8 codepoint semantics for native str (#9423): every op is swept
against live CPython results on multibyte inputs."""
import ctypes;
import from tests.support { compile_native, native_str_func as get_sfunc }

glob SAMPLES: list[str] = [
         "",
         "a",
         "héllo",
         "日本語",
         "a日b本c",
         "🙂x🙂",
         "café",
         "abcabc",
         "è",
         "éèé"
     ],
     MALFORMED: list[bytes] = [
         b"\xf0",
         b"a\xc3",
         b"\xa8\xa8",
         b"\xe2\x82",
         b"x\xf0\x9f",
         b"\xc3\xa8\xa8",
         b"\xff\xfez",
         b"\xed\xa0\x80z",
         b"\xc0\xaf",
         b"\xf4\x90\x80\x80",
         b"a\x80b",
         b"ab\x80",
         b"\xc3\xa9\x80x"
     ],
     _ENGINE: list[any] = [];

def _eng -> any {
    if not _ENGINE {
        (eng, _) = compile_native("str_utf8_cps.jac");
        _ENGINE.append(eng);
    }
    return _ENGINE[0];
}

"""Split bytes the way the native ops do: a unit starts at byte 0 and at every
byte that is not a continuation byte."""
def _units(raw: bytes) -> list[bytes] {
    out: list[bytes] = [];
    for (i, x) in enumerate(raw) {
        if i == 0 or (x & 0xC0) != 0x80 {
            out.append(bytes([x]));
        } else {
            out[-1] = out[-1] + bytes([x]);
        }
    }
    return out;
}

"""Strip whole units, matching each against the units of the charset."""
def _unit_strip(raw: bytes, chars: bytes, left: bool, right: bool) -> bytes {
    units = _units(raw);
    charset = set(_units(chars));
    lo = 0;
    hi = len(units);
    while left and lo < hi and units[lo] in charset {
        lo += 1;
    }
    while right and hi > lo and units[hi - 1] in charset {
        hi -= 1;
    }
    return b"".join(units[lo:hi]);
}

def _unit_char(unit: bytes) -> bytes {
    try {
        text = unit.decode("utf-8", "surrogatepass");
    } except UnicodeDecodeError {
        return "�".encode("utf-8");
    }
    return unit if len(text) == 1 else "�".encode("utf-8");
}

test "str len/index/slice/find are codepoint-oriented on utf-8" {
    STRS = ["", "a", "héllo", "日本語", "a日b本c", "🙂x🙂", "café", "abcabc", "a\tb", "x\t日"];
    NEEDLES = ["", "a", "é", "日", "x", "llo", "日本", "🙂", "abc"];
    BOUNDS = [-12, -5, -3, -1, 0, 1, 2, 4, 7, 12];
    STEPS = [-3, -2, -1, 1, 2, 3];
    (eng, _) = compile_native("str_utf8_cps.jac");
    cp_len = get_sfunc(eng, "cp_len", ctypes.c_int64, ctypes.c_char_p);
    cp_at = get_sfunc(eng, "cp_at", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64);
    cp_ord_at = get_sfunc(
        eng, "cp_ord_at", ctypes.c_int64, ctypes.c_char_p, ctypes.c_int64
    );
    cp_slice = get_sfunc(
        eng,
        "cp_slice",
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64
    );
    cp_slice_step = get_sfunc(
        eng,
        "cp_slice_step",
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64
    );
    cp_find = get_sfunc(
        eng,
        "cp_find",
        ctypes.c_int64,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64
    );
    cp_rfind = get_sfunc(
        eng,
        "cp_rfind",
        ctypes.c_int64,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64
    );
    cp_count = get_sfunc(
        eng,
        "cp_count",
        ctypes.c_int64,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64
    );
    cp_startswith = get_sfunc(
        eng,
        "cp_startswith",
        ctypes.c_bool,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64
    );
    cp_endswith = get_sfunc(
        eng,
        "cp_endswith",
        ctypes.c_bool,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64
    );
    cp_iter = get_sfunc(eng, "cp_iter", ctypes.c_char_p, ctypes.c_char_p);
    cp_reverse = get_sfunc(eng, "cp_reverse", ctypes.c_char_p, ctypes.c_char_p);
    cp_ljust = get_sfunc(
        eng, "cp_ljust", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64
    );
    cp_rjust = get_sfunc(
        eng, "cp_rjust", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64
    );
    cp_center = get_sfunc(
        eng, "cp_center", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64
    );
    cp_zfill = get_sfunc(
        eng, "cp_zfill", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64
    );
    cp_expandtabs = get_sfunc(
        eng, "cp_expandtabs", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64
    );
    cp_isascii = get_sfunc(eng, "cp_isascii", ctypes.c_bool, ctypes.c_char_p);

    for s in STRS {
        sb = s.encode("utf-8");
        assert cp_len(sb) == len(s) , f"len({s!r}) na={cp_len(sb)} sv={len(s)}";
        assert cp_reverse(sb).decode() == s[::-1];
        want_iter = "".join(ch + "|" for ch in s);
        assert cp_iter(sb).decode() == want_iter , f"iter({s!r})";
        for i in range(len(s)) {
            assert cp_at(sb, i).decode() == s[i] , f"{s!r}[{i}]";
            assert cp_at(sb, i - len(s)).decode() == s[i - len(s)] , f"{s!r}[{i
                - len(s)}]";
            assert cp_ord_at(sb, i) == ord(s[i]);
        }
        assert bool(cp_isascii(sb)) == s.isascii() , f"{s!r}.isascii()";
        for w in [-5, -1, 0, 1, 3, 6, 10] {
            assert cp_ljust(sb, w).decode() == s.ljust(w) , f"{s!r}.ljust({w})";
            assert cp_rjust(sb, w).decode() == s.rjust(w) , f"{s!r}.rjust({w})";
            assert cp_center(sb, w).decode() == s.center(w) , f"{s!r}.center({w})";
            assert cp_zfill(sb, w).decode() == s.zfill(w) , f"{s!r}.zfill({w})";
        }
        for t in [-3, 0, 1, 4, 8] {
            assert cp_expandtabs(sb, t).decode() == s.expandtabs(t) , (
                f"{s!r}.expandtabs({t})"
            );
        }
        for a in BOUNDS {
            for bb in BOUNDS {
                assert cp_slice(sb, a, bb).decode() == s[a:bb] , f"{s!r}[{a}:{bb}]";
                for k in STEPS {
                    got = cp_slice_step(sb, a, bb, k).decode();
                    assert got == s[a:bb:k] , f"{s!r}[{a}:{bb}:{k}] na={got!r} sv={s[a:bb:k]!r}";
                }
                for n in NEEDLES {
                    nb = n.encode("utf-8");
                    assert cp_find(sb, nb, a, bb) == s.find(n, a, bb) , (
                        f"{s!r}.find({n!r},{a},{bb}) na={cp_find(sb, nb, a, bb)} sv={s.find(
                            n, a, bb
                        )}"
                    );
                    assert cp_rfind(sb, nb, a, bb) == s.rfind(n, a, bb) , (
                        f"{s!r}.rfind({n!r},{a},{bb}) na={cp_rfind(sb, nb, a, bb)} sv={s.rfind(
                            n, a, bb
                        )}"
                    );
                    assert cp_count(sb, nb, a, bb) == s.count(n, a, bb) , (
                        f"{s!r}.count({n!r},{a},{bb}) na={cp_count(sb, nb, a, bb)} sv={s.count(
                            n, a, bb
                        )}"
                    );
                    assert bool(cp_startswith(sb, nb, a, bb))
                        == s.startswith(n, a, bb) , (
                        f"{s!r}.startswith({n!r},{a},{bb})"
                    );
                    assert bool(cp_endswith(sb, nb, a, bb)) == s.endswith(n, a, bb) , (
                        f"{s!r}.endswith({n!r},{a},{bb})"
                    );
                }
            }
        }
    }
}

test "huge slice steps stop at the ends of a multibyte string" {
    eng = _eng();
    rev = get_sfunc(eng, "cp_rev_huge", ctypes.c_char_p, ctypes.c_char_p);
    fwd = get_sfunc(eng, "cp_fwd_huge", ctypes.c_char_p, ctypes.c_char_p);
    rev_from = get_sfunc(
        eng, "cp_rev_huge_from", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64
    );
    for s in SAMPLES {
        assert rev(s).decode() == s[::-1000000000000] , f"{s!r}[::-10**12]";
        assert fwd(s).decode() == s[::1000000000000] , f"{s!r}[::10**12]";
        for a in [-4, -1, 0, 1, 2, 5] {
            assert rev_from(s, a).decode() == s[a::-1000000000000] , (
                f"{s!r}[{a}::-10**12]"
            );
        }
    }
}

test "malformed utf-8 stays inside its buffer" {
    eng = _eng();
    cp_len = get_sfunc(eng, "cp_len", ctypes.c_int64, ctypes.c_char_p);
    cp_at = get_sfunc(eng, "cp_at", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64);
    cp_iter = get_sfunc(eng, "cp_iter", ctypes.c_char_p, ctypes.c_char_p);
    cp_reverse = get_sfunc(eng, "cp_reverse", ctypes.c_char_p, ctypes.c_char_p);
    cp_slice = get_sfunc(
        eng,
        "cp_slice",
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64
    );
    cp_slice_step = get_sfunc(
        eng,
        "cp_slice_step",
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64
    );
    for raw in MALFORMED {
        units = _units(raw);
        assert cp_len(raw) == len(units) , f"len({raw!r})";
        assert cp_reverse(raw) == b"".join(units[::-1]) , f"{raw!r}[::-1]";
        assert cp_iter(raw) == b"".join([_unit_char(u) + b"|" for u in units]) , (
            f"iter({raw!r})"
        );
        for i in range(len(units)) {
            assert cp_at(raw, i) == _unit_char(units[i]) , f"{raw!r}[{i}]";
        }
        for a in [-3, -1, 0, 1, 2, 4] {
            for b in [-3, -1, 0, 1, 2, 4] {
                assert cp_slice(raw, a, b) == b"".join(units[a:b]) , (
                    f"{raw!r}[{a}:{b}]"
                );
                for k in [-2, -1, 1, 2] {
                    assert cp_slice_step(raw, a, b, k) == b"".join(units[a:b:k]) , (
                        f"{raw!r}[{a}:{b}:{k}]"
                    );
                }
            }
        }
    }
}

test "strip with a charset removes whole codepoints" {
    eng = _eng();
    fns = {
        "strip": get_sfunc(
            eng, "cp_strip", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p
        ),
        "lstrip": get_sfunc(
            eng, "cp_lstrip", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p
        ),
        "rstrip": get_sfunc(
            eng, "cp_rstrip", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p
        )
    };
    assert fns["strip"]("è", "é").decode() == "è";
    sides = {"strip": (True, True), "lstrip": (True, False), "rstrip": (False, True)};
    for raw in MALFORMED
        + [b"\xa9", b"\xa9x\xa9", b"\xa9\xc3\xa9", b"\xc3\xa9\xa9\xa9"] {
        for chars in [b"\xc3\xa9", b"\xa9", b"\xe2\x82\xac\xa9", b"x", b"a\xc3"] {
            for (name, fn) in fns.items() {
                (left, right) = sides[name];
                assert fn(raw, chars) == _unit_strip(raw, chars, left, right) , (
                    f"{raw!r}.{name}({chars!r})"
                );
            }
        }
    }
    for s in SAMPLES + ["éaé", "日日x日", "🙂é🙂"] {
        for chars in ["é", "è", "日", "a日", "🙂", "xé", "c", ""] {
            for (name, fn) in fns.items() {
                want = getattr(s, name)(chars);
                assert fn(s, chars).decode() == want , f"{s!r}.{name}({chars!r})";
            }
        }
    }
}

test "f-string precision and width count codepoints" {
    eng = _eng();
    prec = get_sfunc(eng, "cp_fprec", ctypes.c_char_p, ctypes.c_char_p);
    width = get_sfunc(eng, "cp_fwidth", ctypes.c_char_p, ctypes.c_char_p);
    both = get_sfunc(eng, "cp_fboth", ctypes.c_char_p, ctypes.c_char_p);
    right = get_sfunc(eng, "cp_fright", ctypes.c_char_p, ctypes.c_char_p);
    assert prec("日本語").decode() == f"[{'日本語':.2}]";
    assert width("é").decode() == f"[{'é':3}]";
    for s in SAMPLES {
        assert prec(s).decode() == f"[{s:.2}]" , f"{s!r}:.2";
        assert width(s).decode() == f"[{s:3}]" , f"{s!r}:3";
        assert both(s).decode() == f"[{s:>5.2}]" , f"{s!r}:>5.2";
        assert right(s).decode() == f"[{s:>4}]" , f"{s!r}:>4";
    }
}

test "string views index, slice and iterate by codepoint" {
    eng = _eng();
    view_len = get_sfunc(
        eng, "cp_view_len", ctypes.c_int64, ctypes.c_char_p, ctypes.c_int64
    );
    view_at = get_sfunc(
        eng,
        "cp_view_at",
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64
    );
    view_iter = get_sfunc(
        eng, "cp_view_iter", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64
    );
    view_slice = get_sfunc(
        eng,
        "cp_view_slice",
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64
    );
    view_rev = get_sfunc(
        eng, "cp_view_rev", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64
    );
    owned_view_len = get_sfunc(
        eng, "cp_owned_view_len", ctypes.c_int64, ctypes.c_char_p, ctypes.c_int64
    );
    owned_at = get_sfunc(
        eng, "cp_owned_at", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64
    );
    static_views = get_sfunc(eng, "cp_static_views", ctypes.c_char_p);
    t = "héllo wörld";
    tv = t[3:];
    w = "abcdef"[1:];
    want_static = f"{len(tv)}|{tv[0]}|{tv[-1]}|{len(w)}|{w[2]}|"
        + tv[1:4]
        + "|"
        + w[::-1];
    assert static_views().decode() == want_static;
    for s in SAMPLES + ["abcdefgh", "x" * 40 + "é"] {
        for a in [-3, 0, 1, 2] {
            v = s[a:];
            assert view_len(s, a) == len(v) , f"len({s!r}[{a}:])";
            assert view_iter(s, a).decode() == "".join([ch + "|" for ch in v]) , (
                f"iter({s!r}[{a}:])"
            );
            assert view_rev(s, a).decode() == v[::-1] , f"{s!r}[{a}:][::-1]";
            for i in range(-len(v), len(v)) {
                assert view_at(s, a, i).decode() == v[i] , f"{s!r}[{a}:][{i}]";
            }
            for (b, c) in [(0, 2), (1, -1), (-2, 9), (2, 1)] {
                assert view_slice(s, a, b, c).decode() == v[b:c] , (
                    f"{s!r}[{a}:][{b}:{c}]"
                );
            }
            o = "<" + s;
            assert owned_view_len(s, a) == len(o[a:]) , f"len(<{s!r}[{a}:])";
        }
        o2 = s + ">";
        for i in range(-len(o2), len(o2)) {
            assert owned_at(s, i).decode() == o2[i] , f"({s!r}+'>')[{i}]";
        }
    }
}

test "concatenation keeps codepoint length and indexing right" {
    eng = _eng();
    flags = get_sfunc(eng, "cp_concat_flags", ctypes.c_char_p);
    (a, e) = ("ab", "é");
    (x, y, z, w) = (a + a, a + e, e + a, a + e + a);
    want = f"{len(x)}|{len(y)}|{len(z)}|{len(w)}|{y[2]}|{z[0]}|{w[-1]}|" + x[::-1];
    assert flags().decode() == want , f"concat flags: {flags().decode()!r} != {want!r}";
    cat_len = get_sfunc(
        eng, "cp_concat_len", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p
    );
    cat_at = get_sfunc(
        eng,
        "cp_concat_at",
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64
    );
    for s in SAMPLES {
        for t in SAMPLES {
            u = s + t;
            assert cat_len(s, t) == len(u) , f"len({s!r}+{t!r})";
            for i in range(-len(u), len(u)) {
                assert cat_at(s, t, i).decode() == u[i] , f"({s!r}+{t!r})[{i}]";
            }
        }
    }
}
