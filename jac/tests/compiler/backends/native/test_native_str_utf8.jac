"""UTF-8 codepoint semantics for native str (#9423): every op is swept
against live CPython results on multibyte inputs."""
import ctypes;
import from tests.support { compile_native, native_str_func as get_sfunc }

test "str len/index/slice/find are codepoint-oriented on utf-8" {
    STRS = ["", "a", "héllo", "日本語", "a日b本c", "🙂x🙂", "café", "abcabc"];
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
        for w in [0, 1, 3, 6, 10] {
            assert cp_ljust(sb, w).decode() == s.ljust(w) , f"{s!r}.ljust({w})";
            assert cp_rjust(sb, w).decode() == s.rjust(w) , f"{s!r}.rjust({w})";
            assert cp_center(sb, w).decode() == s.center(w) , f"{s!r}.center({w})";
            assert cp_zfill(sb, w).decode() == s.zfill(w) , f"{s!r}.zfill({w})";
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
