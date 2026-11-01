"""Differential fuzz of the bundled native `re` against CPython's `re`.

A fixed-seed generator (its own LCG, identical on both backends) builds random
patterns from the grammar the native engine supports: literals, `.`, classes
and class escapes, anchors, backreferences, capturing, non-capturing, lookahead
and scoped-flag groups, alternation, and greedy/lazy `*`/`+`/`?`/`{m,n}`
quantifiers, under a rotating set of flags. Each pattern runs against random
subjects (ASCII letters, digits, space, `-`, newline, and a non-ASCII
codepoint that is neither a word, digit nor space character in either engine) through `search`,
`match`, `fullmatch`, `search` with pos/endpos, `finditer`, `findall`, `sub`,
`subn` and `split`, recording every group span. Each row holds the pattern,
flags, subject and results, so a mismatch names the exact case.
"""

import re;


obj _Rng_py {
    has x: int = 0;
}


def _nx_py(r: _Rng_py, k: int) -> int {
    r.x = (r.x * 1103515245 + 12345) % 2147483648;
    return (r.x >> 8) % k;
}


def _pick_py(r: _Rng_py, opts: list[str]) -> str {
    return opts[_nx_py(r, len(opts))];
}


def _atom_py(r: _Rng_py, d: int, g: list[int]) -> str {
    k: int = _nx_py(r, 14 if d < 2 else 9);
    if k <= 3 {
        return _pick_py(r, ["a", "b", "c", "A", "-", "ab", " ", "\u20ac"]);
    }
    if k == 4 {
        return ".";
    }
    if k == 5 {
        return _pick_py(
            r, ["[ab]", "[^a]", "[a-c]", "\\d", "\\w", "\\s", "\\W", "[^\\s]", "[A-Za]"]
        );
    }
    if k == 6 {
        return _pick_py(r, ["^", "$", "\\b", "\\B", "\\A", "\\Z"]);
    }
    if k == 7 {
        if g[0] > 0 {
            return "\\" + str(1 + _nx_py(r, g[0]));
        }
        return "a";
    }
    if k == 8 {
        return "b";
    }
    if k <= 10 {
        g[0] += 1;
        return "(" + _alt_py(r, d + 1, g) + ")";
    }
    if k == 11 {
        return "(?:" + _alt_py(r, d + 1, g) + ")";
    }
    if k == 12 {
        return _pick_py(r, ["(?=", "(?!"]) + _alt_py(r, d + 1, g) + ")";
    }
    return "(?i:" + _alt_py(r, d + 1, g) + ")";
}


def _piece_py(r: _Rng_py, d: int, g: list[int]) -> str {
    a: str = _atom_py(r, d, g);
    q: str = _pick_py(r, ["", "", "", "*", "+", "?", "{1,2}", "{2}", "{0,1}", "{2,}"]);
    if q != "" and _nx_py(r, 3) == 0 {
        q += "?";
    }
    return a + q;
}


def _seq_py(r: _Rng_py, d: int, g: list[int]) -> str {
    n: int = 1 + _nx_py(r, 3);
    out: str = "";
    i: int = 0;
    while i < n {
        out += _piece_py(r, d, g);
        i += 1;
    }
    return out;
}


def _alt_py(r: _Rng_py, d: int, g: list[int]) -> str {
    out: str = _seq_py(r, d, g);
    if _nx_py(r, 4) == 0 {
        out += "|" + _seq_py(r, d, g);
    }
    return out;
}


def _subj_py(r: _Rng_py) -> str {
    n: int = _nx_py(r, 11);
    out: str = "";
    i: int = 0;
    while i < n {
        out += _pick_py(
            r, ["a", "b", "c", "A", "B", "-", "1", " ", "\n", "a", "b", "\u20ac"]
        );
        i += 1;
    }
    return out;
}


def _spans_py(m: (re.Match | None), ng: int) -> str {
    if m is None {
        return "N";
    }
    mm: re.Match = m;
    out: str = "";
    g: int = 0;
    while g <= ng {
        out += str(mm.start(g)) + "," + str(mm.end(g)) + ";";
        g += 1;
    }
    return out;
}


def _case_py(pat: str, fl: int, s: str) -> str {
    try {
        p = re.compile(pat, fl);
    } except Exception {
        return "E";
    }
    ng: int = p.groups;
    out: str = "s=" + _spans_py(p.search(s), ng);
    out += " m=" + _spans_py(p.match(s), ng);
    out += " f=" + _spans_py(p.fullmatch(s), ng);
    out += " p=" + _spans_py(p.search(s, 1, len(s) - 1), ng);
    it: str = "";
    for m in p.finditer(s) {
        it += _spans_py(m, ng) + "|";
    }
    out += " i=" + it;
    if ng <= 1 {
        fa: str = "";
        for x in p.findall(s) {
            fa += x + "|";
        }
        out += " a=" + fa;
    }
    out += " u=" + p.sub("<\\g<0>>", s);
    out += " n=" + str(p.subn("#", s, 2)[1]);
    sp: str = "";
    for y in p.split(s) {
        if y is None {
            sp += "N|";
        } else {
            ys: str = str(y);
            sp += ys + "|";
        }
    }
    out += " t=" + sp;
    return out;
}


def re_fuzz_py -> dict[str, any] {
    out: dict[str, any] = {};
    r: _Rng_py = _Rng_py();
    r.x = 20261022;
    flags: list[int] = [0, 0, 0, re.I, re.M, re.S, re.I | re.M];
    i: int = 0;
    while i < 300 {
        g: list[int] = [0];
        pat: str = _alt_py(r, 0, g);
        fl: int = flags[_nx_py(r, len(flags))];
        j: int = 0;
        while j < 3 {
            s: str = _subj_py(r);
            out["c" + str(i) + "_" + str(j)] = (
                pat
                + " /"
                + str(int(fl))
                + " "
                + repr(s)
                + " => "
                + _case_py(pat, fl, s)
            );
            j += 1;
        }
        i += 1;
    }
    return out;
}

obj _Rng_na {
    has x: int = 0;
}


def _nx_na(r: _Rng_na, k: int) -> int {
    r.x = (r.x * 1103515245 + 12345) % 2147483648;
    return (r.x >> 8) % k;
}


def _pick_na(r: _Rng_na, opts: list[str]) -> str {
    return opts[_nx_na(r, len(opts))];
}


def _atom_na(r: _Rng_na, d: int, g: list[int]) -> str {
    k: int = _nx_na(r, 14 if d < 2 else 9);
    if k <= 3 {
        return _pick_na(r, ["a", "b", "c", "A", "-", "ab", " ", "\u20ac"]);
    }
    if k == 4 {
        return ".";
    }
    if k == 5 {
        return _pick_na(
            r, ["[ab]", "[^a]", "[a-c]", "\\d", "\\w", "\\s", "\\W", "[^\\s]", "[A-Za]"]
        );
    }
    if k == 6 {
        return _pick_na(r, ["^", "$", "\\b", "\\B", "\\A", "\\Z"]);
    }
    if k == 7 {
        if g[0] > 0 {
            return "\\" + str(1 + _nx_na(r, g[0]));
        }
        return "a";
    }
    if k == 8 {
        return "b";
    }
    if k <= 10 {
        g[0] += 1;
        return "(" + _alt_na(r, d + 1, g) + ")";
    }
    if k == 11 {
        return "(?:" + _alt_na(r, d + 1, g) + ")";
    }
    if k == 12 {
        return _pick_na(r, ["(?=", "(?!"]) + _alt_na(r, d + 1, g) + ")";
    }
    return "(?i:" + _alt_na(r, d + 1, g) + ")";
}


def _piece_na(r: _Rng_na, d: int, g: list[int]) -> str {
    a: str = _atom_na(r, d, g);
    q: str = _pick_na(r, ["", "", "", "*", "+", "?", "{1,2}", "{2}", "{0,1}", "{2,}"]);
    if q != "" and _nx_na(r, 3) == 0 {
        q += "?";
    }
    return a + q;
}


def _seq_na(r: _Rng_na, d: int, g: list[int]) -> str {
    n: int = 1 + _nx_na(r, 3);
    out: str = "";
    i: int = 0;
    while i < n {
        out += _piece_na(r, d, g);
        i += 1;
    }
    return out;
}


def _alt_na(r: _Rng_na, d: int, g: list[int]) -> str {
    out: str = _seq_na(r, d, g);
    if _nx_na(r, 4) == 0 {
        out += "|" + _seq_na(r, d, g);
    }
    return out;
}


def _subj_na(r: _Rng_na) -> str {
    n: int = _nx_na(r, 11);
    out: str = "";
    i: int = 0;
    while i < n {
        out += _pick_na(
            r, ["a", "b", "c", "A", "B", "-", "1", " ", "\n", "a", "b", "\u20ac"]
        );
        i += 1;
    }
    return out;
}


def _spans_na(m: (re.Match | None), ng: int) -> str {
    if m is None {
        return "N";
    }
    mm: re.Match = m;
    out: str = "";
    g: int = 0;
    while g <= ng {
        out += str(mm.start(g)) + "," + str(mm.end(g)) + ";";
        g += 1;
    }
    return out;
}


def _case_na(pat: str, fl: int, s: str) -> str {
    try {
        p = re.compile(pat, fl);
    } except Exception {
        return "E";
    }
    ng: int = p.groups;
    out: str = "s=" + _spans_na(p.search(s), ng);
    out += " m=" + _spans_na(p.match(s), ng);
    out += " f=" + _spans_na(p.fullmatch(s), ng);
    out += " p=" + _spans_na(p.search(s, 1, len(s) - 1), ng);
    it: str = "";
    for m in p.finditer(s) {
        it += _spans_na(m, ng) + "|";
    }
    out += " i=" + it;
    if ng <= 1 {
        fa: str = "";
        for x in p.findall(s) {
            fa += x + "|";
        }
        out += " a=" + fa;
    }
    out += " u=" + p.sub("<\\g<0>>", s);
    out += " n=" + str(p.subn("#", s, 2)[1]);
    sp: str = "";
    for y in p.split(s) {
        if y is None {
            sp += "N|";
        } else {
            ys: str = str(y);
            sp += ys + "|";
        }
    }
    out += " t=" + sp;
    return out;
}


def re_fuzz_na -> dict[str, any] {
    out: dict[str, any] = {};
    r: _Rng_na = _Rng_na();
    r.x = 20261022;
    flags: list[int] = [0, 0, 0, re.I, re.M, re.S, re.I | re.M];
    i: int = 0;
    while i < 300 {
        g: list[int] = [0];
        pat: str = _alt_na(r, 0, g);
        fl: int = flags[_nx_na(r, len(flags))];
        j: int = 0;
        while j < 3 {
            s: str = _subj_na(r);
            out["c" + str(i) + "_" + str(j)] = (
                pat
                + " /"
                + str(int(fl))
                + " "
                + repr(s)
                + " => "
                + _case_na(pat, fl, s)
            );
            j += 1;
        }
        i += 1;
    }
    return out;
}


def re_fuzz_cl -> dict[any, any] {
    return {};
}
