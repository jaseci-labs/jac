"""Codepoint index, slice and search on long non-ASCII strings stay linear.

Native strings are UTF-8, so a codepoint index, a slice bound or a search
result on non-ASCII text converts between codepoints and bytes. Each thread
keeps a small cursor cache per long string (a codepoint count, its byte
offset and the total length), so a loop over `s[i]`, `s[i:i + 1]` or
`s.find(x, i + 1)` walks from the last position instead of from byte 0. The
cache drops a string's cursor before its memory is freed, so a new string at
the same address never inherits it.

The fixture's checksums are recomputed here on CPython, over strings long
enough for the cache to engage, including strings rebuilt at the same address
round after round. The scaling test times the four loops at n and 4n
codepoints: linear work grows about 4x, while converting from byte 0 every
step grows about 16x.
"""
import ctypes;
import time;
import from jaclang.compiler.backends.native.llvm.binding { ExecutionEngine }
import from tests.support { compile_native, native_str_func as get_sfunc }

glob MOD: int = 1000000007,
     TEXTS: list[str] = [
         "héllo wörld " * 12,
         "a" * 70 + "é" + "b" * 70,
         "日本語のテキスト、" * 9 + "end",
         "🙂x" * 40 + "tail",
         "x" * 63 + "é",
         "αβγ" * 30 + "abc" * 10 + "δ" * 25
     ],
     NEEDLES: list[str] = ["", "é", "l", "wö", "本", "🙂x", "b", "δ", "zz"],
     _ENGINE: list[ExecutionEngine] = [];

def _eng -> ExecutionEngine {
    if not _ENGINE {
        (eng, _) = compile_native("str_utf8_cursor.jac");
        _ENGINE.append(eng);
    }
    return _ENGINE[0];
}

def _mix(acc: int, v: int) -> int {
    return (acc * 31 + v + 7) % MOD;
}

def _next(x: int) -> int {
    return (x * 1103515245 + 12345) % 2147483648;
}

def _index_mix(s: str, seed: int, steps: int) -> int {
    (n, x, acc) = (len(s), seed, len(s));
    for _ in range(steps) {
        x = _next(x);
        acc = _mix(acc, ord(s[x % (2 * n) - n]));
    }
    return acc;
}

def _walk_both(s: str) -> int {
    acc = 0;
    for i in range(len(s)) {
        acc = _mix(acc, ord(s[i]));
    }
    for i in range(len(s) - 1, -1, -2) {
        acc = _mix(acc, ord(s[i]) + i);
    }
    return acc;
}

def _slice_mix(s: str, seed: int, steps: int) -> int {
    (n, x, acc) = (len(s), seed, 0);
    for _ in range(steps) {
        x = _next(x);
        a = x % (2 * n + 6) - n - 3;
        x = _next(x);
        c = x % (2 * n + 6) - n - 3;
        t = s[a:c];
        acc = _mix(acc, len(t));
        if t {
            acc = _mix(acc, ord(t[0]) + ord(t[-1]) + ord(t[len(t) // 2]));
        }
    }
    return acc;
}

def _view_mix(s: str, seed: int, steps: int) -> int {
    t = s[3:len(s) - 2];
    u = t[5:];
    (x, acc) = (seed, len(t) + len(u));
    for _ in range(steps) {
        x = _next(x);
        acc = _mix(acc, ord(t[x % len(t)]) + ord(u[x % len(u)]) + ord(s[x % len(s)]));
        acc = _mix(acc, len(u[x % len(u):]));
    }
    return acc;
}

def _search_mix(s: str, needle: str, seed: int, steps: int) -> int {
    (n, x, acc) = (len(s), seed, 0);
    for _ in range(steps) {
        x = _next(x);
        a = x % (2 * n + 6) - n - 3;
        x = _next(x);
        c = x % (2 * n + 6) - n - 3;
        acc = _mix(acc, s.find(needle, a, c) + 2);
        acc = _mix(acc, s.rfind(needle, a, c) + 2);
        acc = _mix(acc, s.count(needle, a, c));
        acc = _mix(acc, 1 if s.startswith(needle, a, c) else 0);
        acc = _mix(acc, 1 if s.endswith(needle, a, c) else 0);
    }
    return acc;
}

def _find_walk(s: str, needle: str) -> int {
    acc = 0;
    i = s.find(needle);
    while i >= 0 {
        acc = _mix(acc, i);
        i = s.find(needle, i + 1);
    }
    i = s.rfind(needle);
    while i >= 0 {
        acc = _mix(acc, i);
        i = s.rfind(needle, 0, i);
    }
    return acc;
}

def _round_text(r: int) -> str {
    lead = r % 37;
    return "a" * lead
        + "é" * 30
        + "b" * (37 - lead)
        + "語" * 10
        + "c" * (r % 5)
        + "d" * (5 - r % 5);
}

def _reuse_mix(rounds: int) -> int {
    acc = 0;
    for r in range(rounds) {
        s = _round_text(r);
        acc = _mix(acc, ord(s[40]) + ord(s[-3]) + s.find("b") + len(s));
        acc = _mix(acc, ord(s[len(s) // 2]) + len(s[10:70]) + s.rfind("é"));
        acc = _mix(acc, ord(s[41]) + s.find("語", 50));
    }
    return acc;
}

def _churn_walk(s: str) -> int {
    acc = 0;
    for i in range(len(s)) {
        t = s[i:i + 80] + "é";
        acc = _mix(acc, ord(s[i]) + len(t) + ord(t[len(t) // 2]));
    }
    return acc;
}

test "codepoint access on long non-ASCII strings matches CPython" {
    eng = _eng();
    index_mix = get_sfunc(
        eng,
        "index_mix",
        ctypes.c_int64,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64
    );
    walk_both = get_sfunc(eng, "walk_both", ctypes.c_int64, ctypes.c_char_p);
    slice_mix = get_sfunc(
        eng,
        "slice_mix",
        ctypes.c_int64,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64
    );
    view_mix = get_sfunc(
        eng, "view_mix", ctypes.c_int64, ctypes.c_char_p, ctypes.c_int64, ctypes.c_int64
    );
    churn_walk = get_sfunc(eng, "churn_walk", ctypes.c_int64, ctypes.c_char_p);
    for text in TEXTS {
        raw = text.encode("utf-8");
        for seed in [1, 77, 4242] {
            assert index_mix(raw, seed, 300) == _index_mix(text, seed, 300) , (
                f"index {text[:12]!r} seed {seed}"
            );
            assert slice_mix(raw, seed, 200) == _slice_mix(text, seed, 200) , (
                f"slice {text[:12]!r} seed {seed}"
            );
            assert view_mix(raw, seed, 200) == _view_mix(text, seed, 200) , (
                f"view {text[:12]!r} seed {seed}"
            );
        }
        assert walk_both(raw) == _walk_both(text) , f"walk {text[:12]!r}";
        assert churn_walk(raw) == _churn_walk(text) , f"churn {text[:12]!r}";
    }
}

test "searches on long non-ASCII strings match CPython" {
    eng = _eng();
    search_mix = get_sfunc(
        eng,
        "search_mix",
        ctypes.c_int64,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_int64
    );
    find_walk = get_sfunc(
        eng, "find_walk", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p
    );
    for text in TEXTS {
        raw = text.encode("utf-8");
        for needle in NEEDLES {
            sub = needle.encode("utf-8");
            assert search_mix(raw, sub, 9, 120) == _search_mix(text, needle, 9, 120) , (
                f"search {text[:12]!r} for {needle!r}"
            );
            if needle {
                assert find_walk(raw, sub) == _find_walk(text, needle) , (
                    f"find walk {text[:12]!r} for {needle!r}"
                );
            }
        }
    }
}

test "a string rebuilt at a freed string's address gets no stale cursor" {
    reuse_mix = get_sfunc(_eng(), "reuse_mix", ctypes.c_int64, ctypes.c_int64);
    assert reuse_mix(400) == _reuse_mix(400);
}

test "index, slice and search loops on non-ASCII text scale linearly" {
    eng = _eng();
    lines: list[str] = [];
    for name in ["scan_index", "scan_slice", "scan_find", "scan_rfind"] {
        scan = get_sfunc(eng, name, ctypes.c_int64, ctypes.c_char_p);
        timings: list[float] = [];
        for size in [10000, 40000] {
            text = "ab" * (size // 2 - 1) + "a·";
            raw = text.encode("utf-8");
            assert scan(raw) == size // 2 , f"{name} {size}";
            best = 1e9;
            for _ in range(3) {
                start = time.perf_counter();
                scan(raw);
                best = min(best, time.perf_counter() - start);
            }
            timings.append(best);
        }
        lines.append(f"{name}: {timings[0]:.4f}s -> {timings[1]:.4f}s");
        assert timings[1] < 8 * timings[0] + 0.02 , (
            f"{name} grew superlinearly: " + "; ".join(lines)
        );
    }
}
