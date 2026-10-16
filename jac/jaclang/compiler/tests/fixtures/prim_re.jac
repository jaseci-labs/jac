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
elements, `len`, element indexing). `sem*` pin the cases where a POSIX
leftmost-longest matcher and Python's backtracking matcher disagree (which
span wins, what a repeated group last captured), `cls_*` and `esc_caret` pin
the class escapes libc spells differently per platform, and `many`/`old_ok`
compile more distinct patterns than the libc program registry holds, so the
oldest programs are released while their `Pattern` objects keep answering.
`flags*` pin `Pattern.flags` as CPython reports it. `err*` pin the
pattern-compile error paths
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
    } except Exception as e {
        e1 = str(e);
    }
    e2: str = "no raise";
    try {
        re.compile("a**");
    } except Exception as e {
        e2 = str(e);
    }
    e3: str = "no raise";
    try {
        re.compile("(?i)x(?i)y");
    } except Exception as e {
        e3 = str(e);
    }
    e4: str = "no raise";
    try {
        re.compile("[z-a]");
    } except Exception as e {
        e4 = str(e);
    }
    e5: str = "no raise";
    try {
        re.compile("(a)\\2");
    } except Exception as e {
        e5 = str(e);
    }
    e6: str = "no raise";
    try {
        re.compile("\\123");
        m123 = re.match("\\123", "S");
        e6 = m123.group(0) if m123 is not None else "nomatch";
    } except Exception as e {
        e6 = str(e);
    }
    e7: str = "no raise";
    try {
        re.compile("\\777");
    } except Exception as e {
        e7 = str(e);
    }
    e8: str = "no raise";
    try {
        re.compile("\\128");
    } except Exception as e {
        e8 = str(e);
    }
    e9: str = "no raise";
    try {
        re.compile("\\x0g");
    } except Exception as e {
        e9 = str(e);
    }
    e10: str = "no raise";
    try {
        re.compile("a{3,2}");
    } except Exception as e {
        e10 = str(e);
    }
    e11: str = "no raise";
    try {
        re.compile("(\\1)");
    } except Exception as e {
        e11 = str(e);
    }
    e12: str = "no raise";
    try {
        re.sub("(a)", "\\g<1a>", "a");
    } except Exception as e {
        e12 = str(e);
    }
    e13: str = "no raise";
    try {
        re.sub("(a)", "\\g<>", "a");
    } except Exception as e {
        e13 = str(e);
    }
    e14: str = "no raise";
    try {
        re.sub("(a)", "\\g<", "a");
    } except Exception as e {
        e14 = str(e);
    }
    e15: str = "no raise";
    try {
        re.sub("(a)", "\\g<2>", "a");
    } except Exception as e {
        e15 = str(e);
    }
    e16: str = "no raise";
    try {
        re.sub("(a)", "\\9", "a");
    } except Exception as e {
        e16 = str(e);
    }
    e17: str = "no raise";
    try {
        re.compile("(a)(b)(c)(d)(e)(f)(g)(h)(i)\\12");
    } except Exception as e {
        e17 = str(e);
    }
    e18: str = "no raise";
    try {
        re.compile("[\\400]");
    } except Exception as e {
        e18 = str(e);
    }
    e19: str = "no raise";
    try {
        re.compile("a\\");
    } except Exception as e {
        e19 = str(e);
    }
    e20: str = "no raise";
    try {
        re.compile("(a)\\1234");
        m12 = re.match("(a)\\1234", "aS4");
        e20 = m12.group(0) if m12 is not None else "nomatch";
    } except Exception as e {
        e20 = str(e);
    }
    moct = re.match("\\101", "A");
    moctv: str = moct.group(0) if moct is not None else "nomatch";
    mb0 = re.match("\\0", chr(0));
    mb0v: str = "hit" if mb0 is not None else "nomatch";
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

    sem1 = re.match("x*(xy)?", "xxy");
    sem1g: str = "none";
    if sem1 is not None {
        sem1g = sem1.group(0);
    }
    sem2 = re.search("[bc][ab]c?c+[bc]?", "bcacacc");
    sem2s: int = -1;
    sem2e: int = -1;
    if sem2 is not None {
        sem2s = sem2.start();
        sem2e = sem2.end();
    }
    sem3 = re.match("[bc]b*[bc]{1,2}", "bcbbc");
    sem3e: int = -1;
    if sem3 is not None {
        sem3e = sem3.end();
    }
    sem4 = re.match("(a*)*b", "aab");
    sem4g: str = "none";
    if sem4 is not None {
        sem4g = sem4.group(1);
    }
    sem5 = re.findall("[bc][ab]c?c+[bc]?", "bcacacc");
    cls_w = re.findall("\\w+", "hello w_1");
    cls_s = re.split("\\s", "a b");
    cls_ns = re.findall("\\S+", " ab ");
    cls_nw = re.findall("\\W", "a-b");
    esc_caret = re.findall("\\^a]", "x^a]");
    old_pat = re.compile("q+z");
    many: int = 0;
    mi: int = 0;
    while mi < 700 {
        if re.search("a" + str(mi) + "b+", "xa" + str(mi) + "bb") is not None {
            many += 1;
        }
        if re.search("a" + str(mi) + "b+", "xa" + str(mi) + "c") is None {
            many += 1;
        }
        mi += 1;
    }
    old_ok: bool = old_pat.search("xqqz") is not None and old_pat.search("xqq") is None;
    return {
        "sem1": sem1g,
        "sem2": str(sem2s) + "," + str(sem2e),
        "sem3": sem3e,
        "sem4": sem4g,
        "sem5n": len(sem5),
        "sem5a": sem5[0],
        "cls_wn": len(cls_w),
        "cls_w0": cls_w[0],
        "cls_w1": cls_w[1],
        "cls_sn": len(cls_s),
        "cls_s0": cls_s[0],
        "cls_s1": cls_s[1],
        "cls_nsn": len(cls_ns),
        "cls_ns0": cls_ns[0],
        "cls_nwn": len(cls_nw),
        "cls_nw0": cls_nw[0],
        "esc_caretn": len(esc_caret),
        "esc_caret0": esc_caret[0],
        "many": many,
        "old_ok": old_ok,
        "flags0": re.compile("a").flags,
        "flags_i": re.compile("a", re.I).flags,
        "flags_inline": re.compile("(?i)a").flags,
        "flags_a": re.compile("a", re.A).flags,
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
        "e5": e5,
        "e6": e6,
        "e7": e7,
        "e8": e8,
        "e9": e9,
        "e10": e10,
        "e11": e11,
        "e12": e12,
        "e21": "hit" if re.search("(a)\\1", "aa") is not None else "nomatch",
        "e13": e13,
        "e14": e14,
        "e15": e15,
        "e16": e16,
        "e17": e17,
        "e18": e18,
        "e19": e19,
        "e20": e20,
        "moct": moctv,
        "mb0": mb0v
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
    } except Exception as e {
        e1 = str(e);
    }
    e2: str = "no raise";
    try {
        re.compile("a**");
    } except Exception as e {
        e2 = str(e);
    }
    e3: str = "no raise";
    try {
        re.compile("(?i)x(?i)y");
    } except Exception as e {
        e3 = str(e);
    }
    e4: str = "no raise";
    try {
        re.compile("[z-a]");
    } except Exception as e {
        e4 = str(e);
    }
    e5: str = "no raise";
    try {
        re.compile("(a)\\2");
    } except Exception as e {
        e5 = str(e);
    }
    e6: str = "no raise";
    try {
        re.compile("\\123");
        m123 = re.match("\\123", "S");
        e6 = m123.group(0) if m123 is not None else "nomatch";
    } except Exception as e {
        e6 = str(e);
    }
    e7: str = "no raise";
    try {
        re.compile("\\777");
    } except Exception as e {
        e7 = str(e);
    }
    e8: str = "no raise";
    try {
        re.compile("\\128");
    } except Exception as e {
        e8 = str(e);
    }
    e9: str = "no raise";
    try {
        re.compile("\\x0g");
    } except Exception as e {
        e9 = str(e);
    }
    e10: str = "no raise";
    try {
        re.compile("a{3,2}");
    } except Exception as e {
        e10 = str(e);
    }
    e11: str = "no raise";
    try {
        re.compile("(\\1)");
    } except Exception as e {
        e11 = str(e);
    }
    e12: str = "no raise";
    try {
        re.sub("(a)", "\\g<1a>", "a");
    } except Exception as e {
        e12 = str(e);
    }
    e13: str = "no raise";
    try {
        re.sub("(a)", "\\g<>", "a");
    } except Exception as e {
        e13 = str(e);
    }
    e14: str = "no raise";
    try {
        re.sub("(a)", "\\g<", "a");
    } except Exception as e {
        e14 = str(e);
    }
    e15: str = "no raise";
    try {
        re.sub("(a)", "\\g<2>", "a");
    } except Exception as e {
        e15 = str(e);
    }
    e16: str = "no raise";
    try {
        re.sub("(a)", "\\9", "a");
    } except Exception as e {
        e16 = str(e);
    }
    e17: str = "no raise";
    try {
        re.compile("(a)(b)(c)(d)(e)(f)(g)(h)(i)\\12");
    } except Exception as e {
        e17 = str(e);
    }
    e18: str = "no raise";
    try {
        re.compile("[\\400]");
    } except Exception as e {
        e18 = str(e);
    }
    e19: str = "no raise";
    try {
        re.compile("a\\");
    } except Exception as e {
        e19 = str(e);
    }
    e20: str = "no raise";
    try {
        re.compile("(a)\\1234");
        m12 = re.match("(a)\\1234", "aS4");
        e20 = m12.group(0) if m12 is not None else "nomatch";
    } except Exception as e {
        e20 = str(e);
    }
    moct = re.match("\\101", "A");
    moctv: str = moct.group(0) if moct is not None else "nomatch";
    mb0 = re.match("\\0", chr(0));
    mb0v: str = "hit" if mb0 is not None else "nomatch";
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

    sem1 = re.match("x*(xy)?", "xxy");
    sem1g: str = "none";
    if sem1 is not None {
        sem1g = sem1.group(0);
    }
    sem2 = re.search("[bc][ab]c?c+[bc]?", "bcacacc");
    sem2s: int = -1;
    sem2e: int = -1;
    if sem2 is not None {
        sem2s = sem2.start();
        sem2e = sem2.end();
    }
    sem3 = re.match("[bc]b*[bc]{1,2}", "bcbbc");
    sem3e: int = -1;
    if sem3 is not None {
        sem3e = sem3.end();
    }
    sem4 = re.match("(a*)*b", "aab");
    sem4g: str = "none";
    if sem4 is not None {
        sem4g = sem4.group(1);
    }
    sem5 = re.findall("[bc][ab]c?c+[bc]?", "bcacacc");
    cls_w = re.findall("\\w+", "hello w_1");
    cls_s = re.split("\\s", "a b");
    cls_ns = re.findall("\\S+", " ab ");
    cls_nw = re.findall("\\W", "a-b");
    esc_caret = re.findall("\\^a]", "x^a]");
    old_pat = re.compile("q+z");
    many: int = 0;
    mi: int = 0;
    while mi < 700 {
        if re.search("a" + str(mi) + "b+", "xa" + str(mi) + "bb") is not None {
            many += 1;
        }
        if re.search("a" + str(mi) + "b+", "xa" + str(mi) + "c") is None {
            many += 1;
        }
        mi += 1;
    }
    old_ok: bool = old_pat.search("xqqz") is not None and old_pat.search("xqq") is None;
    return {
        "sem1": sem1g,
        "sem2": str(sem2s) + "," + str(sem2e),
        "sem3": sem3e,
        "sem4": sem4g,
        "sem5n": len(sem5),
        "sem5a": sem5[0],
        "cls_wn": len(cls_w),
        "cls_w0": cls_w[0],
        "cls_w1": cls_w[1],
        "cls_sn": len(cls_s),
        "cls_s0": cls_s[0],
        "cls_s1": cls_s[1],
        "cls_nsn": len(cls_ns),
        "cls_ns0": cls_ns[0],
        "cls_nwn": len(cls_nw),
        "cls_nw0": cls_nw[0],
        "esc_caretn": len(esc_caret),
        "esc_caret0": esc_caret[0],
        "many": many,
        "old_ok": old_ok,
        "flags0": re.compile("a").flags,
        "flags_i": re.compile("a", re.I).flags,
        "flags_inline": re.compile("(?i)a").flags,
        "flags_a": re.compile("a", re.A).flags,
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
        "e5": e5,
        "e6": e6,
        "e7": e7,
        "e8": e8,
        "e9": e9,
        "e10": e10,
        "e11": e11,
        "e12": e12,
        "e21": "hit" if re.search("(a)\\1", "aa") is not None else "nomatch",
        "e13": e13,
        "e14": e14,
        "e15": e15,
        "e16": e16,
        "e17": e17,
        "e18": e18,
        "e19": e19,
        "e20": e20,
        "moct": moctv,
        "mb0": mb0v
    };
}
