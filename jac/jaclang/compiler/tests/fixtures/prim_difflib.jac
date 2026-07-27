"""Bundled native `difflib` cross-backend equivalence fixture (#6978 Phase 3).

The SAME `import from difflib { Match, SequenceMatcher, get_close_matches }` binds
CPython's `difflib` on the sv (Python) backend and the bundled
`na_stdlib/difflib.na.jac` Mechanism-B module on the na (native LLVM) backend.

`ratio()` is exercised through its exact integer ingredients (sum of matching-
block sizes `M` and `len(a)+len(b)`) rather than the raw float, and matching
blocks / `get_close_matches` results are probed via `len(...)` and scalar reads,
since lists marshal as raw i64 across the harness. The `aj*` keys pin the
autojunk popular-element pruning against CPython on a `len(b) == 200` input
where autojunk=True and autojunk=False genuinely differ (a popular run that no
non-popular seed can extend into), `g4*` pins the equal-ratio tie-break
(descending word order, per heapq.nlargest), `g5*` pins explicit n=/cutoff=
keywords, and `err*` pin the ValueError paths. ES/JS opts out.
"""

import from difflib { Match, SequenceMatcher, get_close_matches }


def difflib_py -> dict {
    sm1 = SequenceMatcher(None, "abcde", "abfde");
    bl1: list[Match] = sm1.get_matching_blocks();
    m1: int = 0;
    i1: int = 0;
    while i1 < len(bl1) {
        m1 += bl1[i1].size;
        i1 += 1;
    }
    sm2 = SequenceMatcher(None, "kitten", "sitting");
    bl2: list[Match] = sm2.get_matching_blocks();
    m2: int = 0;
    i2: int = 0;
    while i2 < len(bl2) {
        m2 += bl2[i2].size;
        i2 += 1;
    }
    g1 = get_close_matches("appel", ["ape", "apple", "peach", "puppy", "apples"]);
    g2 = get_close_matches("wrod", ["word", "ward", "world", "words", "sword"]);
    g3 = get_close_matches("zzz", ["aaa", "bbb"]);
    g4 = get_close_matches("abc", ["abd", "abe"]);
    g5 = get_close_matches(
        "wrod", ["word", "ward", "world", "words", "sword"], n=2, cutoff=0.5
    );

    aj_a: str = "abqxxxx";
    aj_b: str = "abz";
    xi: int = 0;
    while xi < 197 {
        aj_b += "x";
        xi += 1;
    }
    sm3 = SequenceMatcher(None, aj_a, aj_b);
    bl3: list[Match] = sm3.get_matching_blocks();
    m3: int = 0;
    i3: int = 0;
    while i3 < len(bl3) {
        m3 += bl3[i3].size;
        i3 += 1;
    }
    sm4 = SequenceMatcher(None, aj_a, aj_b, False);
    bl4: list[Match] = sm4.get_matching_blocks();
    m4: int = 0;
    i4: int = 0;
    while i4 < len(bl4) {
        m4 += bl4[i4].size;
        i4 += 1;
    }

    errn: str = "no raise";
    try {
        get_close_matches("a", ["a"], 0);
    } except ValueError {
        errn = "ValueError";
    }
    errc: str = "no raise";
    try {
        get_close_matches("a", ["a"], 3, 1.5);
    } except ValueError {
        errc = "ValueError";
    }
    return {
        "m1": m1,
        "l1": len("abcde") + len("abfde"),
        "nb1": len(bl1),
        "b1i": bl1[0].a,
        "b1j": bl1[0].b,
        "b1k": bl1[0].size,
        "m2": m2,
        "l2": len("kitten") + len("sitting"),
        "g1n": len(g1),
        "g1_0": g1[0],
        "g1_1": g1[1],
        "g1_2": g1[2],
        "g2n": len(g2),
        "g2_0": g2[0],
        "g3n": len(g3),
        "g4n": len(g4),
        "g4_0": g4[0],
        "g4_1": g4[1],
        "g5n": len(g5),
        "g5_0": g5[0],
        "g5_1": g5[1],
        "ajblen": len(aj_b),
        "ajm_on": m3,
        "ajnb_on": len(bl3),
        "ajm_off": m4,
        "ajnb_off": len(bl4),
        "ajb1i": bl4[1].a,
        "ajb1j": bl4[1].b,
        "ajb1k": bl4[1].size,
        "errn": errn,
        "errc": errc
    };
}


cl def difflib_cl -> dict {
    return {};
}


na {
    def difflib_na -> dict[str, any] {
        sm1: SequenceMatcher = SequenceMatcher(None, "abcde", "abfde");
        bl1: list[Match] = sm1.get_matching_blocks();
        m1: int = 0;
        i1: int = 0;
        while i1 < len(bl1) {
            m1 += bl1[i1].size;
            i1 += 1;
        }
        sm2: SequenceMatcher = SequenceMatcher(None, "kitten", "sitting");
        bl2: list[Match] = sm2.get_matching_blocks();
        m2: int = 0;
        i2: int = 0;
        while i2 < len(bl2) {
            m2 += bl2[i2].size;
            i2 += 1;
        }
        g1: list[str] = get_close_matches(
            "appel", ["ape", "apple", "peach", "puppy", "apples"]
        );
        g2: list[str] = get_close_matches(
            "wrod", ["word", "ward", "world", "words", "sword"]
        );
        g3: list[str] = get_close_matches("zzz", ["aaa", "bbb"]);
        g4: list[str] = get_close_matches("abc", ["abd", "abe"]);
        g5: list[str] = get_close_matches(
            "wrod", ["word", "ward", "world", "words", "sword"], n=2, cutoff=0.5
        );

        aj_a: str = "abqxxxx";
        aj_b: str = "abz";
        xi: int = 0;
        while xi < 197 {
            aj_b += "x";
            xi += 1;
        }
        sm3: SequenceMatcher = SequenceMatcher(None, aj_a, aj_b);
        bl3: list[Match] = sm3.get_matching_blocks();
        m3: int = 0;
        i3: int = 0;
        while i3 < len(bl3) {
            m3 += bl3[i3].size;
            i3 += 1;
        }
        sm4: SequenceMatcher = SequenceMatcher(None, aj_a, aj_b, False);
        bl4: list[Match] = sm4.get_matching_blocks();
        m4: int = 0;
        i4: int = 0;
        while i4 < len(bl4) {
            m4 += bl4[i4].size;
            i4 += 1;
        }

        errn: str = "no raise";
        try {
            get_close_matches("a", ["a"], 0);
        } except ValueError {
            errn = "ValueError";
        }
        errc: str = "no raise";
        try {
            get_close_matches("a", ["a"], 3, 1.5);
        } except ValueError {
            errc = "ValueError";
        }
        return {
            "m1": m1,
            "l1": len("abcde") + len("abfde"),
            "nb1": len(bl1),
            "b1i": bl1[0].a,
            "b1j": bl1[0].b,
            "b1k": bl1[0].size,
            "m2": m2,
            "l2": len("kitten") + len("sitting"),
            "g1n": len(g1),
            "g1_0": g1[0],
            "g1_1": g1[1],
            "g1_2": g1[2],
            "g2n": len(g2),
            "g2_0": g2[0],
            "g3n": len(g3),
            "g4n": len(g4),
            "g4_0": g4[0],
            "g4_1": g4[1],
            "g5n": len(g5),
            "g5_0": g5[0],
            "g5_1": g5[1],
            "ajblen": len(aj_b),
            "ajm_on": m3,
            "ajnb_on": len(bl3),
            "ajm_off": m4,
            "ajnb_off": len(bl4),
            "ajb1i": bl4[1].a,
            "ajb1j": bl4[1].b,
            "ajb1k": bl4[1].size,
            "errn": errn,
            "errc": errc
        };
    }
}
