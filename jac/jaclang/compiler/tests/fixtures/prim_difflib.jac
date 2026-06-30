"""Bundled native `difflib` cross-backend equivalence fixture (#6978 Phase 3).

The SAME `import from difflib { SequenceMatcher, get_close_matches }` binds
CPython's `difflib` on the sv (Python) backend and the bundled
`na_stdlib/difflib.na.jac` Mechanism-B module on the na (native LLVM) backend.

`ratio()` is exercised through its exact integer ingredients (sum of matching-
block sizes `M` and `len(a)+len(b)`) rather than the raw float, and matching
blocks / `get_close_matches` results are probed via `len(...)` and scalar reads,
since lists marshal as raw i64 across the harness. Sequences are short (<200), so
CPython's autojunk never engages and the two are congruent. ES/JS opts out.
"""

import from difflib { SequenceMatcher, get_close_matches }


def difflib_py -> dict {
    sm1 = SequenceMatcher(None, "abcde", "abfde");
    bl1 = sm1.get_matching_blocks();
    m1: int = 0;
    i1: int = 0;
    while i1 < len(bl1) {
        m1 += bl1[i1][2];
        i1 += 1;
    }
    sm2 = SequenceMatcher(None, "kitten", "sitting");
    bl2 = sm2.get_matching_blocks();
    m2: int = 0;
    i2: int = 0;
    while i2 < len(bl2) {
        m2 += bl2[i2][2];
        i2 += 1;
    }
    g1 = get_close_matches("appel", ["ape", "apple", "peach", "puppy", "apples"]);
    g2 = get_close_matches("wrod", ["word", "ward", "world", "words", "sword"]);
    g3 = get_close_matches("zzz", ["aaa", "bbb"]);
    return {
        "m1": m1,
        "l1": len("abcde") + len("abfde"),
        "nb1": len(bl1),
        "b1i": bl1[0][0],
        "b1j": bl1[0][1],
        "b1k": bl1[0][2],
        "m2": m2,
        "l2": len("kitten") + len("sitting"),
        "g1n": len(g1),
        "g1_0": g1[0],
        "g1_1": g1[1],
        "g1_2": g1[2],
        "g2n": len(g2),
        "g2_0": g2[0],
        "g3n": len(g3)
    };
}


cl def difflib_cl -> dict {
    return {};
}


na {
    def difflib_na -> dict[str, any] {
        sm1: SequenceMatcher = SequenceMatcher(None, "abcde", "abfde");
        bl1: list[list[int]] = sm1.get_matching_blocks();
        m1: int = 0;
        i1: int = 0;
        while i1 < len(bl1) {
            m1 += bl1[i1][2];
            i1 += 1;
        }
        sm2: SequenceMatcher = SequenceMatcher(None, "kitten", "sitting");
        bl2: list[list[int]] = sm2.get_matching_blocks();
        m2: int = 0;
        i2: int = 0;
        while i2 < len(bl2) {
            m2 += bl2[i2][2];
            i2 += 1;
        }
        g1: list[str] = get_close_matches(
            "appel", ["ape", "apple", "peach", "puppy", "apples"]
        );
        g2: list[str] = get_close_matches(
            "wrod", ["word", "ward", "world", "words", "sword"]
        );
        g3: list[str] = get_close_matches("zzz", ["aaa", "bbb"]);
        return {
            "m1": m1,
            "l1": len("abcde") + len("abfde"),
            "nb1": len(bl1),
            "b1i": bl1[0][0],
            "b1j": bl1[0][1],
            "b1k": bl1[0][2],
            "m2": m2,
            "l2": len("kitten") + len("sitting"),
            "g1n": len(g1),
            "g1_0": g1[0],
            "g1_1": g1[1],
            "g1_2": g1[2],
            "g2n": len(g2),
            "g2_0": g2[0],
            "g3n": len(g3)
        };
    }
}
