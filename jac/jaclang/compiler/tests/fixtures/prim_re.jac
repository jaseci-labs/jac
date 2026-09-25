"""Bundled native `re` cross-backend equivalence fixture (#6978 Phase 3).

The SAME `import re` binds CPython's `re` on the sv (Python) backend and the
bundled `na_stdlib/re.jac` Mechanism-B module (pure-Jac parser + backtracking
matcher) on the na (native LLVM) backend. Only the congruent subset is
exercised: literals, classes, anchors, greedy/lazy bounded repeats, alternation,
numbered/named groups, backrefs, lookahead, inline flags, search/match/
fullmatch/findall/finditer/split/sub/subn/escape/compile. `findall` on a
multi-group pattern and `sub` with a callable replacement are outside the native
module's scope and are not probed.

Match objects, lists, dicts, and tuples marshal as raw i64 across the harness,
so all results are probed through scalar reads (`group`, `start`/`end`/`span`
elements, `len`, element indexing). `err*` pin the pattern-compile error paths
(`except Exception` covers CPython's `re.error`/`PatternError` and the native
`ValueError`). ES/JS opts out.
"""

import re;


def re_py -> dict[any, any] {
    m1 = re.match("(\\d+)-(\\d+)", "12-34");
    g1: str = "none";
    g2: str = "none";
    g0s0: int = -1;
    g0e0: int = -1;
    gsn: int = -1;
    exp: str = "none";
    if m1 is not None {
        g1 = m1.group(1);
        g2 = m1.group(2);
        g0s0 = m1.start();
        g0e0 = m1.end();
        gsn = len(m1.groups());
        exp = m1.expand("[\\1][\\2]");
    }
    m2 = re.search("b+", "aabbbcc");
    mg: str = "none";
    ms: int = -1;
    me: int = -1;
    if m2 is not None {
        mg = m2.group(0);
        ms = m2.start();
        me = m2.end();
    }
    fa1 = re.findall("\\d+", "a1b22c333");
    fa2 = re.findall("(\\w)at", "cat bat rat");
    sp1 = re.split(",\\s*", "a, b,c");
    sp2 = re.split("(\\d+)", "a1b22");
    sb = re.subn("\\d+", "X", "a1b22");
    mn = re.match("(?P<w>\\d+)", "42");
    ng: str = "none";
    gd0: str = "none";
    if mn is not None {
        ng = mn.group("w");
        gd = mn.groupdict();
        gd0 = gd["w"];
    }
    fi_s: list[any] = [];
    fi_e: list[any] = [];
    for mm in re.finditer("\\d+", "a1b22") {
        fi_s.append(mm.start());
        fi_e.append(mm.end());
    }
    e1: str = "no raise";
    try {
        re.compile("(");
    } except Exception {
        e1 = "err";
    }
    e2: str = "no raise";
    try {
        re.compile("a**");
    } except Exception {
        e2 = "err";
    }
    e3: str = "no raise";
    try {
        re.compile("(?i)x(?i)y");
    } except Exception {
        e3 = "err";
    }
    e4: str = "no raise";
    try {
        re.compile("[z-a]");
    } except Exception {
        e4 = "err";
    }
    e5: str = "no raise";
    try {
        re.compile("(a)\\2");
    } except Exception {
        e5 = "err";
    }
    mb = re.search("ABC", "xabcy", re.I);
    ifs: int = -1;
    if mb is not None {
        ifs = mb.start();
    }
    mbc = re.search("\\bcat\\b", "the cat sat");
    bnd: str = "none";
    if mbc is not None {
        bnd = mbc.group(0);
    }
    mx = re.match("(a)", "xabc");
    malt = re.match("a|b|c", "b");
    alt: str = "none";
    if malt is not None {
        alt = malt.group(0);
    }
    mbr = re.match("(\\w)\\1", "aab");
    bref: str = "none";
    if mbr is not None {
        bref = mbr.group(0);
    }
    mla1 = re.match("a(?=b)", "ab");
    la1: str = "none";
    if mla1 is not None {
        la1 = mla1.group(0);
    }
    mla2 = re.match("a(?!b)", "ac");
    la2: str = "none";
    if mla2 is not None {
        la2 = mla2.group(0);
    }
    mifi = re.match("(?i)abc", "ABC");
    mifx = re.match("(?x)a  b", "ab");
    mr23 = re.match("a{2,3}", "aaa");
    r23: int = -1;
    if mr23 is not None {
        r23 = mr23.end();
    }
    mr23l = re.match("a{2,3}?", "aaa");
    r23l: int = -1;
    if mr23l is not None {
        r23l = mr23l.end();
    }
    mr2o = re.match("a{2,}", "aaaa");
    r2o: int = -1;
    if mr2o is not None {
        r2o = mr2o.end();
    }
    mcls1 = re.match("[a-c]+", "abcabd");
    cls1: int = -1;
    if mcls1 is not None {
        cls1 = mcls1.end();
    }
    mcls2 = re.match("[^a-c]+", "xyzabc");
    cls2: int = -1;
    if mcls2 is not None {
        cls2 = mcls2.end();
    }
    mcls3 = re.match("[\\d]+", "421");
    cls3: int = -1;
    if mcls3 is not None {
        cls3 = mcls3.end();
    }
    pz = re.compile("z+");
    mcmp = pz.search("azzb");
    cmp: str = "none";
    if mcmp is not None {
        cmp = mcmp.group(0);
    }
    eneg = re.compile("a").search("aaa", 0, -1);
    en1: str = "matched";
    if eneg is None {
        en1 = "none";
    }
    eempty = re.compile("").search("abc", 0, -1);
    ems: int = -1;
    eme: int = -1;
    if eempty is not None {
        ems = eempty.start();
        eme = eempty.end();
    }
    oc = re.sub("x", "\\0123", "x");
    unc = re.search(".", "\u00e9x");
    ug: str = "none";
    us: int = -1;
    if unc is not None {
        ug = unc.group(0);
        us = unc.end();
    }
    unc2 = re.search("x", "\u00e9x");
    u2s: int = -1;
    if unc2 is not None {
        u2s = unc2.start();
    }
    mqp = re.match("(a*)(a*)", "aa");
    qg1: str = "none";
    qg2: str = "none";
    if mqp is not None {
        qg1 = mqp.group(1);
        qg2 = mqp.group(2);
    }
    mopen = re.match("a{,3}", "aa");
    mo: int = -1;
    if mopen is not None {
        mo = mopen.end();
    }

    return {
        "en1": en1,
        "ems": ems,
        "eme": eme,
        "oc": oc,
        "ug": ug,
        "us": us,
        "u2s": u2s,
        "qg1": qg1,
        "qg2": qg2,
        "mo": mo,
        "g1": g1,
        "g2": g2,
        "g0s0": g0s0,
        "g0e0": g0e0,
        "gs": gsn,
        "mg": mg,
        "ms": ms,
        "me": me,
        "mt1": re.match("a.c", "abc") is not None,
        "mt2": re.match("a.c", "axc") is not None,
        "mt3": re.match("a.c", "ac") is None,
        "fm1": re.fullmatch("a.c", "abc") is not None,
        "fm2": re.fullmatch("a.c", "abcx") is None,
        "fa1n": len(fa1),
        "fa1a": fa1[0],
        "fa1b": fa1[2],
        "fa2a": fa2[0],
        "fa2b": fa2[2],
        "sp1n": len(sp1),
        "sp1a": sp1[0],
        "sp1c": sp1[2],
        "sp2n": len(sp2),
        "sp2b": sp2[1],
        "sp2e": sp2[4],
        "sub1": re.sub("\\d+", "X", "a1b22"),
        "sub2": re.sub("\\d+", "X", "a1b22", count=1),
        "sub3": re.sub("x*", "-", "abxd"),
        "sbn0": sb[0],
        "sbn1": sb[1],
        "ng": ng,
        "gd0": gd0,
        "ifs": ifs,
        "alt": alt,
        "bref": bref,
        "la1": la1,
        "la2": la2,
        "esc": re.escape("a.b*c"),
        "ifi": mifi is not None,
        "ifx": mifx is not None,
        "exp": exp,
        "fin": len(fi_s),
        "fi0s": fi_s[0],
        "fi1e": fi_e[1],
        "r23": r23,
        "r23l": r23l,
        "r2o": r2o,
        "bnd": bnd,
        "cls1": cls1,
        "cls2": cls2,
        "cls3": cls3,
        "nomatch": mx is None,
        "cmp": cmp,
        "e1": e1,
        "e2": e2,
        "e3": e3,
        "e4": e4,
        "e5": e5
    };
}


def re_cl -> dict[any, any] {
    return {};
}


def re_na -> dict[str, any] {
    m1 = re.match("(\\d+)-(\\d+)", "12-34");
    g1: str = "none";
    g2: str = "none";
    g0s0: int = -1;
    g0e0: int = -1;
    gsn: int = -1;
    exp: str = "none";
    if m1 is not None {
        g1 = m1.group(1);
        g2 = m1.group(2);
        g0s0 = m1.start();
        g0e0 = m1.end();
        gsn = len(m1.groups());
        exp = m1.expand("[\\1][\\2]");
    }
    m2 = re.search("b+", "aabbbcc");
    mg: str = "none";
    ms: int = -1;
    me: int = -1;
    if m2 is not None {
        mg = m2.group(0);
        ms = m2.start();
        me = m2.end();
    }
    fa1 = re.findall("\\d+", "a1b22c333");
    fa2 = re.findall("(\\w)at", "cat bat rat");
    sp1 = re.split(",\\s*", "a, b,c");
    sp2 = re.split("(\\d+)", "a1b22");
    sb = re.subn("\\d+", "X", "a1b22");
    mn = re.match("(?P<w>\\d+)", "42");
    ng: str = "none";
    gd0: str = "none";
    if mn is not None {
        ng = mn.group("w");
        gd = mn.groupdict();
        gd0 = gd["w"];
    }
    fi_s: list[any] = [];
    fi_e: list[any] = [];
    for mm in re.finditer("\\d+", "a1b22") {
        fi_s.append(mm.start());
        fi_e.append(mm.end());
    }
    e1: str = "no raise";
    try {
        re.compile("(");
    } except Exception {
        e1 = "err";
    }
    e2: str = "no raise";
    try {
        re.compile("a**");
    } except Exception {
        e2 = "err";
    }
    e3: str = "no raise";
    try {
        re.compile("(?i)x(?i)y");
    } except Exception {
        e3 = "err";
    }
    e4: str = "no raise";
    try {
        re.compile("[z-a]");
    } except Exception {
        e4 = "err";
    }
    e5: str = "no raise";
    try {
        re.compile("(a)\\2");
    } except Exception {
        e5 = "err";
    }
    mb = re.search("ABC", "xabcy", re.I);
    ifs: int = -1;
    if mb is not None {
        ifs = mb.start();
    }
    mbc = re.search("\\bcat\\b", "the cat sat");
    bnd: str = "none";
    if mbc is not None {
        bnd = mbc.group(0);
    }
    mx = re.match("(a)", "xabc");
    malt = re.match("a|b|c", "b");
    alt: str = "none";
    if malt is not None {
        alt = malt.group(0);
    }
    mbr = re.match("(\\w)\\1", "aab");
    bref: str = "none";
    if mbr is not None {
        bref = mbr.group(0);
    }
    mla1 = re.match("a(?=b)", "ab");
    la1: str = "none";
    if mla1 is not None {
        la1 = mla1.group(0);
    }
    mla2 = re.match("a(?!b)", "ac");
    la2: str = "none";
    if mla2 is not None {
        la2 = mla2.group(0);
    }
    mifi = re.match("(?i)abc", "ABC");
    mifx = re.match("(?x)a  b", "ab");
    mr23 = re.match("a{2,3}", "aaa");
    r23: int = -1;
    if mr23 is not None {
        r23 = mr23.end();
    }
    mr23l = re.match("a{2,3}?", "aaa");
    r23l: int = -1;
    if mr23l is not None {
        r23l = mr23l.end();
    }
    mr2o = re.match("a{2,}", "aaaa");
    r2o: int = -1;
    if mr2o is not None {
        r2o = mr2o.end();
    }
    mcls1 = re.match("[a-c]+", "abcabd");
    cls1: int = -1;
    if mcls1 is not None {
        cls1 = mcls1.end();
    }
    mcls2 = re.match("[^a-c]+", "xyzabc");
    cls2: int = -1;
    if mcls2 is not None {
        cls2 = mcls2.end();
    }
    mcls3 = re.match("[\\d]+", "421");
    cls3: int = -1;
    if mcls3 is not None {
        cls3 = mcls3.end();
    }
    pz = re.compile("z+");
    mcmp = pz.search("azzb");
    cmp: str = "none";
    if mcmp is not None {
        cmp = mcmp.group(0);
    }
    eneg = re.compile("a").search("aaa", 0, -1);
    en1: str = "matched";
    if eneg is None {
        en1 = "none";
    }
    eempty = re.compile("").search("abc", 0, -1);
    ems: int = -1;
    eme: int = -1;
    if eempty is not None {
        ems = eempty.start();
        eme = eempty.end();
    }
    oc = re.sub("x", "\\0123", "x");
    unc = re.search(".", "\u00e9x");
    ug: str = "none";
    us: int = -1;
    if unc is not None {
        ug = unc.group(0);
        us = unc.end();
    }
    unc2 = re.search("x", "\u00e9x");
    u2s: int = -1;
    if unc2 is not None {
        u2s = unc2.start();
    }
    mqp = re.match("(a*)(a*)", "aa");
    qg1: str = "none";
    qg2: str = "none";
    if mqp is not None {
        qg1 = mqp.group(1);
        qg2 = mqp.group(2);
    }
    mopen = re.match("a{,3}", "aa");
    mo: int = -1;
    if mopen is not None {
        mo = mopen.end();
    }

    return {
        "en1": en1,
        "ems": ems,
        "eme": eme,
        "oc": oc,
        "ug": ug,
        "us": us,
        "u2s": u2s,
        "qg1": qg1,
        "qg2": qg2,
        "mo": mo,
        "g1": g1,
        "g2": g2,
        "g0s0": g0s0,
        "g0e0": g0e0,
        "gs": gsn,
        "mg": mg,
        "ms": ms,
        "me": me,
        "mt1": re.match("a.c", "abc") is not None,
        "mt2": re.match("a.c", "axc") is not None,
        "mt3": re.match("a.c", "ac") is None,
        "fm1": re.fullmatch("a.c", "abc") is not None,
        "fm2": re.fullmatch("a.c", "abcx") is None,
        "fa1n": len(fa1),
        "fa1a": fa1[0],
        "fa1b": fa1[2],
        "fa2a": fa2[0],
        "fa2b": fa2[2],
        "sp1n": len(sp1),
        "sp1a": sp1[0],
        "sp1c": sp1[2],
        "sp2n": len(sp2),
        "sp2b": sp2[1],
        "sp2e": sp2[4],
        "sub1": re.sub("\\d+", "X", "a1b22"),
        "sub2": re.sub("\\d+", "X", "a1b22", count=1),
        "sub3": re.sub("x*", "-", "abxd"),
        "sbn0": sb[0],
        "sbn1": sb[1],
        "ng": ng,
        "gd0": gd0,
        "ifs": ifs,
        "alt": alt,
        "bref": bref,
        "la1": la1,
        "la2": la2,
        "esc": re.escape("a.b*c"),
        "ifi": mifi is not None,
        "ifx": mifx is not None,
        "exp": exp,
        "fin": len(fi_s),
        "fi0s": fi_s[0],
        "fi1e": fi_e[1],
        "r23": r23,
        "r23l": r23l,
        "r2o": r2o,
        "bnd": bnd,
        "cls1": cls1,
        "cls2": cls2,
        "cls3": cls3,
        "nomatch": mx is None,
        "cmp": cmp,
        "e1": e1,
        "e2": e2,
        "e3": e3,
        "e4": e4,
        "e5": e5
    };
}
