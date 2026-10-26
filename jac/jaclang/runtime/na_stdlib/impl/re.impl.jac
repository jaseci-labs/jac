impl _push_prs(dst: list[int], src: list[int]) {
    k: int = 0;
    while k < len(src) {
        dst.append(src[k]);
        k += 1;
    }
}


impl _in_pairs(pairs: list[int], c: int) -> bool {
    k: int = 0;
    n: int = len(pairs);
    while k + 1 < n {
        if c >= pairs[k] and c <= pairs[k + 1] {
            return True;
        }
        k += 2;
    }
    return False;
}


impl _name_index(names: dict[str, int], nm: str) -> int {
    if nm in names {
        return names[nm];
    }
    return -1;
}


impl _num_esc(cps: list[int], i: int, e: int, bp: int) -> tuple[(int, int)] {
    n: int = len(cps);
    if e == 120 {
        v: int = 0;
        got: int = 0;
        while got < 2 and i < n {
            hv: int = hexv(cps[i]);
            if hv < 0 {
                break;
            }
            v = v * 16 + hv;
            i += 1;
            got += 1;
        }
        if got < 2 {
            raise ValueError(
                "incomplete escape " + cps_str(cps, bp, i) + " at position " + str(bp)
            );
        }
        return (v, i);
    }
    if e == 117 {
        v = 0;
        got = 0;
        while got < 4 and i < n {
            hv = hexv(cps[i]);
            if hv < 0 {
                break;
            }
            v = v * 16 + hv;
            i += 1;
            got += 1;
        }
        if got < 4 {
            raise ValueError(
                "incomplete escape " + cps_str(cps, bp, i) + " at position " + str(bp)
            );
        }
        return (v, i);
    }
    if e == 85 {
        v = 0;
        got = 0;
        while got < 8 and i < n {
            hv = hexv(cps[i]);
            if hv < 0 {
                break;
            }
            v = v * 16 + hv;
            i += 1;
            got += 1;
        }
        if got < 8 {
            raise ValueError(
                "incomplete escape " + cps_str(cps, bp, i) + " at position " + str(bp)
            );
        }
        return (v, i);
    }
    v = e - 48;
    cnt: int = 1;
    while cnt < 3 and i < n {
        d: int = cps[i];
        if d < 48 or d > 55 {
            break;
        }
        v = v * 8 + (d - 48);
        i += 1;
        cnt += 1;
    }
    if v > 255 {
        raise ValueError(
            "octal escape value "
                + cps_str(cps, bp, i)
                + " outside of range 0-0o377 at position "
                + str(bp)
        );
    }
    return (v, i);
}


impl _clamp(v: int, n: int) -> int {
    if v < 0 {
        return 0;
    }
    if v > n {
        return n;
    }
    return v;
}


impl _P._err(msg: str, pos: int) {
    raise ValueError(msg + " at position " + str(pos));
}

impl _P._skip_verbose {
    if (self.flags & 64) == 0 {
        return;
    }
    while self.i < self.n {
        c: int = self.cps[self.i];
        if is_space(c) {
            self.i += 1;
            continue;
        }
        if c == 35 {
            while self.i < self.n and self.cps[self.i] != 10 {
                self.i += 1;
            }
            continue;
        }
        break;
    }
}

impl _P._is_repeat_spec(pos: int) -> bool {
    if pos >= self.n or self.cps[pos] != 123 {
        return False;
    }
    j: int = pos + 1;
    digs: int = 0;
    while j < self.n and is_digit(self.cps[j]) {
        j += 1;
        digs += 1;
    }
    if j < self.n and self.cps[j] == 44 {
        j += 1;
        while j < self.n and is_digit(self.cps[j]) {
            j += 1;
            digs += 1;
        }
    }
    if j >= self.n or self.cps[j] != 125 {
        return False;
    }
    return digs > 0 or j > pos + 2;
}

impl _P._rep_spec(pos: int) -> list[int] {
    j: int = pos + 1;
    lo: int = 0;
    hi: int = -1;
    have_lo: bool = False;
    while j < self.n and is_digit(self.cps[j]) {
        lo = lo * 10 + (self.cps[j] - 48);
        j += 1;
        have_lo = True;
    }
    if j < self.n and self.cps[j] == 44 {
        j += 1;
        hi = -1;
        if j < self.n and is_digit(self.cps[j]) {
            hi = 0;
            while j < self.n and is_digit(self.cps[j]) {
                hi = hi * 10 + (self.cps[j] - 48);
                j += 1;
            }
        }
    } else {
        hi = lo;
    }
    self.i = j + 1;
    if hi >= 0 and lo > hi {
        self._err("min repeat greater than max repeat", pos + 1);
    }
    return [lo, hi];
}

impl _P._atom -> (_Node | None) {
    c: int = self.cps[self.i];
    if c == 40 {
        return self._group();
    }
    if c == 91 {
        return self._class();
    }
    if c == 46 {
        self.i += 1;
        nd: _Node = _Node();
        nd.kind = _K.ANY;
        return nd;
    }
    if c == 94 {
        self.i += 1;
        nd = _Node();
        nd.kind = _K.AT;
        nd.at = _AT.BEGLINE if (self.flags & 8) != 0 else _AT.BEG;
        return nd;
    }
    if c == 36 {
        self.i += 1;
        nd = _Node();
        nd.kind = _K.AT;
        nd.at = _AT.ENDLINE if (self.flags & 8) != 0 else _AT.END;
        return nd;
    }
    if c == 42 or c == 43 or c == 63 {
        self._err("nothing to repeat", self.i);
    }
    if c == 123 and self._is_repeat_spec(self.i) {
        self._err("nothing to repeat", self.i);
    }
    if c == 92 {
        return self._escape_atom();
    }
    self.i += 1;
    nd = _Node();
    nd.kind = _K.CHAR;
    nd.ch = c;
    return nd;
}

impl _P._piece -> (_Node | None) {
    a0: int = self.i;
    atom: (_Node | None) = self._atom();
    if atom is None {
        return None;
    }
    self._skip_verbose();
    if self.i >= self.n {
        return atom;
    }
    c: int = self.cps[self.i];
    if c != 42 and c != 43 and c != 63 and c != 123 {
        return atom;
    }
    if c == 123 and not self._is_repeat_spec(self.i) {
        return atom;
    }
    if atom.kind == _K.AT and self.cps[a0] != 40 {
        self._err("nothing to repeat", self.i);
    }
    lo: int = 0;
    hi: int = -1;
    if c == 42 {
        self.i += 1;
    } elif c == 43 {
        lo = 1;
        self.i += 1;
    } elif c == 63 {
        hi = 1;
        self.i += 1;
    } elif c == 123 {
        if not self._is_repeat_spec(self.i) {
            return atom;
        }
        spec: list[int] = self._rep_spec(self.i);
        lo = spec[0];
        hi = spec[1];
    }
    greedy: bool = True;
    if self.i < self.n {
        nc: int = self.cps[self.i];
        if nc == 63 {
            greedy = False;
            self.i += 1;
        } elif nc == 43 {
            self._err("possessive quantifiers not supported on native", self.i);
        }
    }
    if self.i < self.n {
        nc = self.cps[self.i];
        if nc == 42 or nc == 43 or nc == 63 {
            self._err("multiple repeat", self.i);
        }
        if nc == 123 and self._is_repeat_spec(self.i) {
            self._err("multiple repeat", self.i);
        }
    }
    nd: _Node = _Node();
    nd.kind = _K.REP;
    nd.lo = lo;
    nd.hi = hi;
    nd.greedy = greedy;
    a2: _Node = atom;
    nd.kids.append(a2);
    return nd;
}

impl _P._seq -> _Node {
    kids: list[_Node] = [];
    while True {
        self._skip_verbose();
        if self.i >= self.n {
            break;
        }
        c: int = self.cps[self.i];
        if c == 124 or c == 41 {
            break;
        }
        piece: (_Node | None) = self._piece();
        if piece is None {
            continue;
        }
        kids.append(piece);
        if self.depth == 0 {
            self.top_items += 1;
        }
    }
    if len(kids) == 1 {
        return kids[0];
    }
    nd: _Node = _Node();
    nd.kind = _K.SEQ;
    nd.kids = kids;
    return nd;
}

impl _P._alt -> _Node {
    first: _Node = self._seq();
    if self.i >= self.n or self.cps[self.i] != 124 {
        return first;
    }
    kids: list[_Node] = [];
    kids.append(first);
    while self.i < self.n and self.cps[self.i] == 124 {
        self.i += 1;
        kids.append(self._seq());
    }
    nd: _Node = _Node();
    nd.kind = _K.ALT;
    nd.kids = kids;
    return nd;
}

impl _P._expect_close(open_pos: int) {
    if self.i >= self.n or self.cps[self.i] != 41 {
        self._err("missing ), unterminated subpattern", open_pos);
    }
    self.i += 1;
}

impl _P._flagval(c: int) -> int {
    if c == 105 {
        return 2;
    }
    if c == 109 {
        return 8;
    }
    if c == 115 {
        return 16;
    }
    if c == 120 {
        return 64;
    }
    if c == 97 {
        return 256;
    }
    if c == 117 {
        return 32;
    }
    if c == 76 {
        return 4;
    }
    return 0;
}

impl _P._group -> (_Node | None) {
    p0: int = self.i;
    self.i += 1;
    if self.i >= self.n {
        self._err("missing ), unterminated subpattern", p0);
    }
    if self.cps[self.i] != 63 {
        self.ngroups += 1;
        g: int = self.ngroups;
        self.opengroups.append(g);
        self.depth += 1;
        body: _Node = self._alt();
        self.depth -= 1;
        self.opengroups.pop();
        self._expect_close(p0);
        nd: _Node = _Node();
        nd.kind = _K.GROUP;
        nd.lo = g;
        nd.kids.append(body);
        return nd;
    }
    self.i += 1;
    if self.i >= self.n {
        self._err("missing ), unterminated subpattern", p0);
    }
    c2: int = self.cps[self.i];
    if c2 == 58 {
        self.i += 1;
        self.depth += 1;
        body = self._alt();
        self.depth -= 1;
        self._expect_close(p0);
        return body;
    }
    if c2 == 35 {
        while self.i < self.n and self.cps[self.i] != 41 {
            self.i += 1;
        }
        self._expect_close(p0);
        return None;
    }
    if c2 == 61 or c2 == 33 {
        neg: bool = c2 == 33;
        self.i += 1;
        self.depth += 1;
        body = self._alt();
        self.depth -= 1;
        self._expect_close(p0);
        nd = _Node();
        nd.kind = _K.LOOK;
        nd.lo = 1 if neg else 0;
        nd.kids.append(body);
        return nd;
    }
    if c2 == 80 {
        self.i += 1;
        if self.i < self.n and self.cps[self.i] == 60 {
            self.i += 1;
            nstart: int = self.i;
            while self.i < self.n and self.cps[self.i] != 62 {
                self.i += 1;
            }
            if self.i >= self.n {
                self._err("missing ), unterminated subpattern", p0);
            }
            nm: str = cps_str(self.cps, nstart, self.i);
            if len(nm) == 0 {
                self._err("missing group name", self.i);
            }
            ok: bool = True;
            k: int = 0;
            while k < len(nm) {
                cc: int = ord(nm[k]);
                if not is_word(cc) or (k == 0 and is_digit(cc)) {
                    ok = False;
                }
                k += 1;
            }
            if not ok {
                self._err("bad character in group name '" + nm + "'", nstart);
            }
            self.i += 1;
            old: int = _name_index(self.names, nm);
            if old >= 0 {
                self._err(
                    "redefinition of group name '"
                        + nm
                        + "' as group "
                        + str(self.ngroups + 1)
                        + "; was group "
                        + str(old),
                    self.i - 1
                );
            }
            self.ngroups += 1;
            g = self.ngroups;
            self.names[nm] = g;
            self.opengroups.append(g);
            self.depth += 1;
            body = self._alt();
            self.depth -= 1;
            self.opengroups.pop();
            self._expect_close(p0);
            nd = _Node();
            nd.kind = _K.GROUP;
            nd.lo = g;
            nd.name = nm;
            nd.kids.append(body);
            return nd;
        }
        if self.i < self.n and self.cps[self.i] == 61 {
            self.i += 1;
            ns2: int = self.i;
            while self.i < self.n and self.cps[self.i] != 41 {
                self.i += 1;
            }
            if self.i >= self.n {
                self._err("missing ), unterminated subpattern", p0);
            }
            nm2: str = cps_str(self.cps, ns2, self.i);
            self.i += 1;
            if len(nm2) == 0 {
                self._err("missing group name", ns2);
            }
            k2: int = 0;
            bad2: bool = False;
            while k2 < len(nm2) {
                cc2: int = ord(nm2[k2]);
                if not is_word(cc2) or (k2 == 0 and is_digit(cc2)) {
                    bad2 = True;
                }
                k2 += 1;
            }
            if bad2 {
                self._err("bad character in group name '" + nm2 + "'", ns2);
            }
            gnum2: int = _name_index(self.names, nm2);
            if gnum2 < 0 {
                self._err("unknown group name '" + nm2 + "'", ns2);
            }
            nd = _Node();
            nd.kind = _K.BACKREF;
            nd.lo = gnum2;
            return nd;
        }
        self._err("unknown extension ?P", p0 + 1);
    }
    if c2 == 60 {
        if self.i + 1 < self.n {
            c3: int = self.cps[self.i + 1];
            if c3 == 61 or c3 == 33 {
                self._err("lookbehind not supported on native", self.i);
            }
            self._err("unknown extension ?<" + chr(self.cps[self.i + 1]), p0 + 1);
        }
        self._err("unknown extension ?<", p0 + 1);
    }
    if c2 == 40 {
        self._err("unknown extension ?(", p0 + 1);
    }
    if c2 == 35 {
        while self.i < self.n and self.cps[self.i] != 41 {
            self.i += 1;
        }
        if self.i >= self.n {
            self._err("missing ), unterminated comment", p0);
        }
        self.i += 1;
        return None;
    }
    fv: int = self._flagval(c2);
    if fv != 0 or c2 == 45 or c2 == 58 {
        newf: int = self.flags;
        j: int = self.i;
        while j < self.n {
            fch: int = self._flagval(self.cps[j]);
            if fch == 0 {
                break;
            }
            newf = newf | fch;
            j += 1;
        }
        if j < self.n and self.cps[j] == 45 {
            j += 1;
            while j < self.n {
                fch = self._flagval(self.cps[j]);
                if fch == 0 {
                    break;
                }
                if (newf & fch) != 0 {
                    newf -= fch;
                }
                j += 1;
            }
        }
        if j < self.n and self.cps[j] == 41 {
            self.i = j + 1;
            if self.depth > 0 or self.top_items > 0 {
                self._err("global flags not at the start of the expression", p0);
            }
            self.flags = newf;
            return None;
        }
        if j < self.n and self.cps[j] == 58 {
            self.i = j + 1;
            saved: int = self.flags;
            self.flags = newf;
            self.depth += 1;
            body = self._alt();
            self.depth -= 1;
            self._expect_close(p0);
            self.flags = saved;
            nd = _Node();
            nd.kind = _K.FLAGS;
            nd.lo = newf;
            nd.kids.append(body);
            return nd;
        }
        self._err("missing -, : or )", j);
    }
    self._err("unknown extension ?" + chr(self.cps[self.i]), p0 + 1);
    return None;
}

impl _P._class_item(pairs: list[int]) -> int {
    c: int = self.cps[self.i];
    if c == 92 {
        bp: int = self.i;
        self.i += 1;
        if self.i >= self.n {
            self._err("bad escape (end of pattern)", bp);
        }
        e: int = self.cps[self.i];
        self.i += 1;
        if e == 100 {
            _push_prs(pairs, _DIGIT_PRS);
            return -1;
        }
        if e == 68 {
            _push_prs(pairs, _NDIGIT_PRS);
            return -1;
        }
        if e == 115 {
            _push_prs(pairs, _SPACE_PRS);
            return -1;
        }
        if e == 83 {
            _push_prs(pairs, _NSPACE_PRS);
            return -1;
        }
        if e == 119 {
            _push_prs(pairs, _WORD_PRS);
            return -1;
        }
        if e == 87 {
            _push_prs(pairs, _NWORD_PRS);
            return -1;
        }
        if e == 98 {
            return 8;
        }
        if e == 110 {
            return 10;
        }
        if e == 114 {
            return 13;
        }
        if e == 116 {
            return 9;
        }
        if e == 102 {
            return 12;
        }
        if e == 118 {
            return 11;
        }
        if e == 97 {
            return 7;
        }
        if (e >= 48 and e <= 55) or e == 120 or e == 117 or e == 85 {
            r: tuple[(int, int)] = _num_esc(self.cps, self.i, e, bp);
            self.i = r[1];
            return r[0];
        }
        if e == 56 or e == 57 {
            self._err("bad escape \\" + chr(self.cps[self.i - 1]), bp);
        }
        if is_alpha(e) {
            self._err("bad escape \\" + chr(self.cps[self.i - 1]), bp);
        }
        return e;
    }
    self.i += 1;
    return c;
}

impl _P._class -> _Node {
    p0: int = self.i;
    self.i += 1;
    nd: _Node = _Node();
    nd.kind = _K.CLASS;
    pairs: list[int] = [];
    first: bool = True;
    if self.i < self.n and self.cps[self.i] == 94 {
        nd.neg = True;
        self.i += 1;
    }
    while True {
        if self.i >= self.n {
            self._err("unterminated character set", p0);
        }
        if self.cps[self.i] == 93 and not first {
            self.i += 1;
            break;
        }
        lo_pos: int = self.i;
        lo: int = self._class_item(pairs);
        first = False;
        if lo < 0 {
            continue;
        }
        if self.i < self.n and self.cps[self.i] == 45 {
            if self.i + 1 < self.n and self.cps[self.i + 1] != 93 {
                self.i += 1;
                hi: int = self._class_item(pairs);
                if hi < 0 {
                    pairs.append(lo);
                    pairs.append(lo);
                    pairs.append(45);
                    pairs.append(45);
                    continue;
                }
                if hi < lo {
                    self._err("bad character range " + chr(lo) + "-" + chr(hi), lo_pos);
                }
                pairs.append(lo);
                pairs.append(hi);
                continue;
            }
            pairs.append(lo);
            pairs.append(lo);
            pairs.append(45);
            pairs.append(45);
            self.i += 1;
            continue;
        }
        pairs.append(lo);
        pairs.append(lo);
    }
    nd.pairs = pairs;
    return nd;
}

impl _P._escape_atom -> _Node {
    bp: int = self.i;
    self.i += 1;
    if self.i >= self.n {
        self._err("bad escape (end of pattern)", bp);
    }
    e: int = self.cps[self.i];
    self.i += 1;
    nd: _Node = _Node();
    if e == 65 {
        nd.kind = _K.AT;
        nd.at = _AT.BOS;
        return nd;
    }
    if e == 90 {
        nd.kind = _K.AT;
        nd.at = _AT.EOS;
        return nd;
    }
    if e == 98 {
        nd.kind = _K.AT;
        nd.at = _AT.WB;
        return nd;
    }
    if e == 66 {
        nd.kind = _K.AT;
        nd.at = _AT.WNB;
        return nd;
    }
    if e == 100 {
        nd.kind = _K.CLASS;
        nd.pairs = _DIGIT_PRS[:];
        return nd;
    }
    if e == 68 {
        nd.kind = _K.CLASS;
        nd.pairs = _NDIGIT_PRS[:];
        return nd;
    }
    if e == 115 {
        nd.kind = _K.CLASS;
        nd.pairs = _SPACE_PRS[:];
        return nd;
    }
    if e == 83 {
        nd.kind = _K.CLASS;
        nd.pairs = _NSPACE_PRS[:];
        return nd;
    }
    if e == 119 {
        nd.kind = _K.CLASS;
        nd.pairs = _WORD_PRS[:];
        return nd;
    }
    if e == 87 {
        nd.kind = _K.CLASS;
        nd.pairs = _NWORD_PRS[:];
        return nd;
    }
    if e >= 48 and e <= 57 {
        if e == 48 {
            r: tuple[(int, int)] = _num_esc(self.cps, self.i, e, bp);
            self.i = r[1];
            nd.kind = _K.CHAR;
            nd.ch = r[0];
            return nd;
        }
        num: int = e - 48;
        ndig: int = 1;
        while ndig < 2 and self.i < self.n and is_digit(self.cps[self.i]) {
            num = num * 10 + (self.cps[self.i] - 48);
            self.i += 1;
            ndig += 1;
        }
        if ndig == 2
            and e >= 48
            and e <= 55
            and self.cps[self.i - 1] >= 48
            and self.cps[self.i - 1] <= 55
            and self.i < self.n
            and self.cps[self.i] >= 48
            and self.cps[self.i] <= 55 {
            v8: int = (e - 48) * 64
                + (self.cps[self.i - 1] - 48) * 8
                + (self.cps[self.i] - 48);
            if v8 > 255 {
                raise ValueError(
                    "octal escape value "
                        + cps_str(self.cps, bp, self.i + 1)
                        + " outside of range 0-0o377 at position "
                        + str(bp)
                );
            }
            self.i += 1;
            nd.kind = _K.CHAR;
            nd.ch = v8;
            return nd;
        }
        if num <= self.ngroups {
            og: int = 0;
            while og < len(self.opengroups) {
                if self.opengroups[og] == num {
                    self._err("cannot refer to an open group", bp);
                }
                og += 1;
            }
            nd.kind = _K.BACKREF;
            nd.lo = num;
            return nd;
        }
        self._err("invalid group reference " + str(num), self.i - ndig);
    }
    if e == 120 or e == 117 or e == 85 {
        r = _num_esc(self.cps, self.i, e, bp);
        self.i = r[1];
        nd.kind = _K.CHAR;
        nd.ch = r[0];
        return nd;
    }
    if e == 78 {
        if self.i < self.n and self.cps[self.i] == 123 {
            j: int = self.i + 1;
            while j < self.n and self.cps[j] != 125 {
                j += 1;
            }
            if j < self.n {
                nm: str = cps_str(self.cps, self.i + 1, j);
                self._err("undefined character name '" + nm + "'", bp);
            }
        }
        self._err("bad escape \\N", bp);
    }
    if e == 110 {
        nd.kind = _K.CHAR;
        nd.ch = 10;
        return nd;
    }
    if e == 114 {
        nd.kind = _K.CHAR;
        nd.ch = 13;
        return nd;
    }
    if e == 116 {
        nd.kind = _K.CHAR;
        nd.ch = 9;
        return nd;
    }
    if e == 102 {
        nd.kind = _K.CHAR;
        nd.ch = 12;
        return nd;
    }
    if e == 118 {
        nd.kind = _K.CHAR;
        nd.ch = 11;
        return nd;
    }
    if e == 97 {
        nd.kind = _K.CHAR;
        nd.ch = 7;
        return nd;
    }
    if is_alpha(e) {
        self._err("bad escape \\" + chr(self.cps[self.i - 1]), bp);
    }
    nd.kind = _K.CHAR;
    nd.ch = e;
    return nd;
}

impl _P._parse -> _Node {
    nd: _Node = self._alt();
    if self.i < self.n {
        self._err("unbalanced parenthesis", self.i);
    }

    return nd;
}


impl _cat(base: int, wide: bool, pos: int) -> int {
    if wide {
        return int(__mem_load_i64(base + pos * 8));
    }
    return int(__mem_load_i8(base + pos));
}


impl _cls_bits(pairs: list[int], neg: bool, icase: bool) -> list[int] {
    bits: list[int] = [0, 0, 0, 0];
    c: int = 0;
    while c < 128 {
        hit: bool = _in_pairs(pairs, c);
        if not hit and icase {
            hit = _in_pairs(pairs, swapcase(c));
        }
        if hit != neg {
            bits[c >> 5] = bits[c >> 5] | (1 << (c & 31));
        }
        c += 1;
    }
    return bits;
}


impl _cls_wide(pairs: list[int], neg: bool) -> bool {
    if neg {
        return True;
    }
    k: int = 1;
    while k < len(pairs) {
        if pairs[k] >= 128 {
            return True;
        }
        k += 2;
    }
    return False;
}


impl _cls_build(pairs: list[int], neg: bool, icase: bool, re: _Re) -> int {
    bits: list[int] = _cls_bits(pairs, neg, icase);
    for w in bits {
        re.cbits.append(w);
    }
    cl: _Cls = _Cls();
    cl.pairs = pairs;
    cl.neg = neg;
    cl.wide = _cls_wide(pairs, neg);
    re.classes.append(cl);
    return len(re.classes) - 1;
}


impl _cls_wide_has(re: _Re, k: int, c: int) -> bool {
    cl: _Cls = re.classes[k];
    if not cl.wide {
        return False;
    }
    return _in_pairs(cl.pairs, c) != cl.neg;
}


impl _item_ok(re: _Re, kind: int, arg: int, c: int) -> bool {
    if kind == _O_CLASS {
        if c < 128 {
            return ((re.cbits[arg * 4 + (c >> 5)] >> (c & 31)) & 1) != 0;
        }
        return _cls_wide_has(re, arg, c);
    }
    if kind == _O_CHAR {
        return c == arg;
    }
    if kind == _O_ANY {
        return c != 10;
    }
    if kind == _O_ANYALL {
        return True;
    }
    return c == (arg & 2097151) or c == (arg >> 21);
}


impl _emit(re: _Re, op: int, a: int, b: int, c: int, d: int) -> int {
    k: int = len(re.prog) // 6;
    re.prog.append(op);
    re.prog.append(a);
    re.prog.append(b);
    re.prog.append(c);
    re.prog.append(d);
    re.prog.append(-1);
    return k;
}


impl _single_item(nd: _Node, flags: int, re: _Re) -> tuple[(int, int)] {
    icase: bool = (flags & 2) != 0;
    if nd.kind == _K.CHAR {
        if icase and is_alpha(nd.ch) {
            return (_O_CHAR2, nd.ch | (swapcase(nd.ch) << 21));
        }
        return (_O_CHAR, nd.ch);
    }
    if nd.kind == _K.ANY {
        if (flags & 16) != 0 {
            return (_O_ANYALL, 0);
        }
        return (_O_ANY, 0);
    }
    if nd.kind == _K.CLASS {
        return (_O_CLASS, _cls_build(nd.pairs, nd.neg, icase, re));
    }
    return (0, 0);
}


impl _compile_node(nd: _Node, re: _Re, flags: int) {
    kind: _K = nd.kind;
    if kind == _K.SEQ {
        for kid in nd.kids {
            _compile_node(kid, re, flags);
        }
        return;
    }
    if kind == _K.ALT {
        splits: list[int] = [];
        jmps: list[int] = [];
        last: int = len(nd.kids) - 1;
        j: int = 0;
        while j < last {
            splits.append(_emit(re, _O_SPLIT, len(re.prog) // 6 + 1, 0, 0, 0));
            _compile_node(nd.kids[j], re, flags);
            jmps.append(_emit(re, _O_JMP, 0, 0, 0, 0));
            j += 1;
        }
        last_start: int = len(re.prog) // 6;
        _compile_node(nd.kids[last], re, flags);
        e: int = len(re.prog) // 6;
        k: int = 0;
        while k < len(splits) {
            if k + 1 < len(splits) {
                re.prog[splits[k] * 6 + 2] = splits[k + 1];
            } else {
                re.prog[splits[k] * 6 + 2] = last_start;
            }
            k += 1;
        }
        for ji in jmps {
            re.prog[ji * 6 + 1] = e;
        }
        return;
    }
    if kind == _K.CHAR or kind == _K.ANY or kind == _K.CLASS {
        it: tuple[(int, int)] = _single_item(nd, flags, re);
        if it[0] == _O_CHAR2 {
            _emit(re, _O_CHAR2, it[1] & 2097151, it[1] >> 21, 0, 0);
        } else {
            _emit(re, it[0], it[1], 0, 0, 0);
        }
        return;
    }
    if kind == _K.AT {
        op: int = _O_BOS;
        if nd.at == _AT.BEGLINE {
            op = _O_BEGLINE;
        } elif nd.at == _AT.END {
            op = _O_END;
        } elif nd.at == _AT.ENDLINE {
            op = _O_ENDLINE;
        } elif nd.at == _AT.EOS {
            op = _O_EOS;
        } elif nd.at == _AT.WB {
            op = _O_WB;
        } elif nd.at == _AT.WNB {
            op = _O_NWB;
        }
        _emit(re, op, 0, 0, 0, 0);
        return;
    }
    if kind == _K.GROUP {
        _emit(re, _O_SAVE, nd.lo * 2, 0, 0, 0);
        _compile_node(nd.kids[0], re, flags);
        _emit(re, _O_SAVE, nd.lo * 2 + 1, 0, 0, 0);
        return;
    }
    if kind == _K.REP {
        kid: _Node = nd.kids[0];
        if kid.kind == _K.CHAR or kid.kind == _K.ANY or kid.kind == _K.CLASS {
            item: tuple[(int, int)] = _single_item(kid, flags, re);
            _emit(
                re, _O_REPG if nd.greedy else _O_REPL, item[0], item[1], nd.lo, nd.hi
            );
            return;
        }
        m: int = 0;
        while m < nd.lo {
            _compile_node(kid, re, flags);
            m += 1;
        }
        if nd.hi < 0 {
            lpos: int = len(re.prog) // 6;
            si: int = 0;
            if nd.greedy {
                si = _emit(re, _O_SPLIT, lpos + 1, 0, 0, 0);
            } else {
                si = _emit(re, _O_SPLIT, 0, lpos + 1, 0, 0);
            }
            mark: int = re.nmarks;
            re.nmarks += 1;
            _emit(re, _O_MARK, mark, 0, 0, 0);
            _compile_node(kid, re, flags);
            _emit(re, _O_JMPNZ, mark, lpos, 0, 0);
            epos: int = len(re.prog) // 6;
            if nd.greedy {
                re.prog[si * 6 + 2] = epos;
            } else {
                re.prog[si * 6 + 1] = epos;
            }
            return;
        }
        splits2: list[int] = [];
        j2: int = nd.lo;
        while j2 < nd.hi {
            nxt: int = len(re.prog) // 6 + 1;
            if nd.greedy {
                splits2.append(_emit(re, _O_SPLIT, nxt, 0, 0, 0));
            } else {
                splits2.append(_emit(re, _O_SPLIT, 0, nxt, 0, 0));
            }
            _compile_node(kid, re, flags);
            j2 += 1;
        }
        epos2: int = len(re.prog) // 6;
        for s2 in splits2 {
            if nd.greedy {
                re.prog[s2 * 6 + 2] = epos2;
            } else {
                re.prog[s2 * 6 + 1] = epos2;
            }
        }
        return;
    }
    if kind == _K.BACKREF {
        _emit(re, _O_BACKREFI if (flags & 2) != 0 else _O_BACKREF, nd.lo, 0, 0, 0);
        return;
    }
    if kind == _K.LOOK {
        li: int = _emit(re, _O_LOOK, 0, nd.lo, 0, 0);
        ji2: int = _emit(re, _O_JMP, 0, 0, 0, 0);
        re.prog[li * 6 + 1] = len(re.prog) // 6;
        _compile_node(nd.kids[0], re, flags);
        _emit(re, _O_MATCH, 0, 0, 0, 0);
        re.prog[ji2 * 6 + 1] = len(re.prog) // 6;
        return;
    }
    if kind == _K.FLAGS {
        _compile_node(nd.kids[0], re, nd.lo);
        return;
    }
}


impl _fs_add(fs: _FS, c: int) {
    if c >= 128 {
        fs.wide = True;
        return;
    }
    fs.bits[c >> 5] = fs.bits[c >> 5] | (1 << (c & 31));
}


impl _first(nd: _Node, flags: int, fs: _FS) -> bool {
    kind: _K = nd.kind;
    if kind == _K.CHAR {
        _fs_add(fs, nd.ch);
        if (flags & 2) != 0 and is_alpha(nd.ch) {
            _fs_add(fs, swapcase(nd.ch));
        }
        return False;
    }
    if kind == _K.ANY {
        c: int = 0;
        while c < 128 {
            if c != 10 or (flags & 16) != 0 {
                _fs_add(fs, c);
            }
            c += 1;
        }
        fs.wide = True;
        return False;
    }
    if kind == _K.CLASS {
        bits: list[int] = _cls_bits(nd.pairs, nd.neg, (flags & 2) != 0);
        w: int = 0;
        while w < 4 {
            fs.bits[w] = fs.bits[w] | bits[w];
            w += 1;
        }
        if _cls_wide(nd.pairs, nd.neg) {
            fs.wide = True;
        }
        return False;
    }
    if kind == _K.GROUP {
        return _first(nd.kids[0], flags, fs);
    }
    if kind == _K.FLAGS {
        return _first(nd.kids[0], nd.lo, fs);
    }
    if kind == _K.SEQ {
        for kid in nd.kids {
            if not _first(kid, flags, fs) {
                return False;
            }
        }
        return True;
    }
    if kind == _K.ALT {
        nl: bool = False;
        for kid2 in nd.kids {
            if _first(kid2, flags, fs) {
                nl = True;
            }
        }
        return nl;
    }
    if kind == _K.REP {
        r: bool = _first(nd.kids[0], flags, fs);
        return r or nd.lo == 0;
    }
    if kind == _K.BACKREF {
        fs.all = True;
        return True;
    }
    return True;
}


impl _analyze(tree: _Node, re: _Re) {
    flags: int = re.flags;
    head: _Node = tree;
    if tree.kind == _K.SEQ and len(tree.kids) > 0 {
        head = tree.kids[0];
    }
    if head.kind == _K.AT and (head.at == _AT.BOS or head.at == _AT.BEG) {
        re.anchored = True;
    }
    if (flags & 2) == 0 {
        pre: str = "";
        if tree.kind == _K.CHAR {
            pre = chr(tree.ch);
        } elif tree.kind == _K.SEQ {
            for kid in tree.kids {
                if kid.kind != _K.CHAR {
                    break;
                }
                pre += chr(kid.ch);
            }
        }
        re.prefix = pre;
        re.plen = len(pre);
        re.pcps = utf8_cps(pre.encode());
    }
    fs: _FS = _FS();
    fs.bits = [0, 0, 0, 0];
    nullable: bool = _first(tree, flags, fs);
    if not nullable and not fs.all {
        re.has_fs = True;
        re.fs = fs.bits;
        re.fs_wide = fs.wide;
    }
}


impl _new_st(re: _Re) -> _St {
    st: _St = _St();
    st.slots = [];
    i: int = 0;
    while i < (re.ngroups + 1) * 2 {
        st.slots.append(-1);
        i += 1;
    }
    st.marks = [];
    i = 0;
    while i < re.nmarks {
        st.marks.append(-1);
        i += 1;
    }
    st.stk = [];
    return st;
}


impl _prep(st: _St, string: str, endpos: int) {
    if string.isascii() {
        st.wide = False;
        st.base = __str_data(string);
    } else {
        cps: list[int] = utf8_cps(string.encode());
        st.cps = cps;
        st.base = __list_data_ptr(cps);
        st.wide = True;
    }
    st.n = endpos;
    st.adv_pos = -1;
    st.match_all = False;
}


impl _grow(st: _St, need: int) -> int {
    add: int = len(st.stk);
    if add < 64 {
        add = 64;
    }
    while len(st.stk) < need {
        i: int = 0;
        while i < add {
            st.stk.append(0);
            i += 1;
        }
    }
    return __list_data_ptr(st.stk);
}


impl _unwind(st: _St, sp0: int, keep_undo: bool) {
    sb: int = __list_data_ptr(st.stk);
    top: int = st.sp;
    if keep_undo {
        r: int = sp0;
        w: int = sp0;
        while r < top {
            tag: int = int(__mem_load_i64(sb + (r + 3) * 8));
            if tag == _T_SAVE or tag == _T_MARK {
                if w != r {
                    __mem_store_i64(sb + w * 8, __mem_load_i64(sb + r * 8));
                    __mem_store_i64(sb + (w + 1) * 8, __mem_load_i64(sb + (r + 1) * 8));
                    __mem_store_i64(sb + (w + 2) * 8, __mem_load_i64(sb + (r + 2) * 8));
                    __mem_store_i64(sb + (w + 3) * 8, tag);
                }
                w += 4;
            }
            r += 4;
        }
        st.sp = w;
        return;
    }
    slp: int = __list_data_ptr(st.slots);
    sp: int = top;
    while sp > sp0 {
        sp -= 4;
        tag2: int = int(__mem_load_i64(sb + (sp + 3) * 8));
        x: int = int(__mem_load_i64(sb + sp * 8));
        y: int = int(__mem_load_i64(sb + (sp + 1) * 8));
        if tag2 == _T_SAVE {
            __mem_store_i64(slp + x * 8, y);
        } elif tag2 == _T_MARK {
            st.marks[x] = y;
        }
    }
    st.sp = sp0;
}


impl _exec(re: _Re, st: _St, pc0: int, start: int, mode: int) -> int {
    pb: int = __list_data_ptr(re.prog);
    cbp: int = __list_data_ptr(re.cbits);
    slp: int = __list_data_ptr(st.slots);
    mkp: int = __list_data_ptr(st.marks);
    sb: int = __list_data_ptr(st.stk);
    cap: int = len(st.stk);
    sp0: int = st.sp;
    sp: int = sp0;
    base: int = st.base;
    wide: bool = st.wide;
    n: int = st.n;
    pc: int = pc0;
    pos: int = start;
    top: bool = mode != 0;
    p: int = start;
    if mode == 2 {
        if start > n {
            return -1;
        }
        if re.anchored {
            if start != 0 {
                return -1;
            }
            mode = 1;
        }
    }
    if mode == 1 and re.has_fs {
        if p >= n {
            return -1;
        }
        c0: int = _cat(base, wide, p);
        if c0 >= 128 {
            if not re.fs_wide {
                return -1;
            }
        } elif ((re.fs[c0 >> 5] >> (c0 & 31)) & 1) == 0 {
            return -1;
        }
    }
    while True {
        if mode == 2 {
            if re.plen > 0 {
                m: int = re.plen;
                first: int = re.pcps[0];
                last: int = n - m;
                got: bool = False;
                while p <= last {
                    if wide {
                        while p <= last
                            and int(__mem_load_i64(base + p * 8)) != first {
                            p += 1;
                        }
                        if p > last {
                            return -1;
                        }
                    } else {
                        hit0: int = memchr(base + p, i32(first), u64(last - p + 1));
                        if hit0 == 0 {
                            return -1;
                        }
                        p = hit0 - base;
                    }
                    j0: int = 1;
                    while j0 < m and _cat(base, wide, p + j0) == re.pcps[j0] {
                        j0 += 1;
                    }
                    if j0 == m {
                        got = True;
                        break;
                    }
                    p += 1;
                }
                if not got {
                    return -1;
                }
            } elif re.has_fs {
                fsw: bool = re.fs_wide;
                while p < n {
                    c1: int = _cat(base, wide, p);
                    if c1 < 128 {
                        if ((re.fs[c1 >> 5] >> (c1 & 31)) & 1) != 0 {
                            break;
                        }
                    } elif fsw {
                        break;
                    }
                    p += 1;
                }
                if p >= n {
                    return -1;
                }
            } elif p > n {
                return -1;
            }
        }
        pc = pc0;
        pos = p;
        res: int = -1;
        while True {
            k: int = pb + pc * 48;
            op: int = int(__mem_load_i64(k));
            if op == _O_CHAR {
                if pos < n and _cat(base, wide, pos) == int(__mem_load_i64(k + 8)) {
                    pos += 1;
                    pc += 1;
                    continue;
                }
            } elif op == _O_CLASS {
                if pos < n {
                    c: int = _cat(base, wide, pos);
                    ca: int = int(__mem_load_i64(k + 8));
                    hit: bool = False;
                    if c < 128 {
                        hit = (
                            (
                                int(__mem_load_i64(cbp + (ca * 4 + (c >> 5)) * 8))
                                >> (c & 31)
                            )
                            & 1
                        )
                            != 0;
                    } else {
                        hit = _cls_wide_has(re, ca, c);
                    }
                    if hit {
                        pos += 1;
                        pc += 1;
                        continue;
                    }
                }
            } elif op == _O_REPG {
                kind: int = int(__mem_load_i64(k + 8));
                arg: int = int(__mem_load_i64(k + 16));
                mn: int = int(__mem_load_i64(k + 24));
                mx: int = int(__mem_load_i64(k + 32));
                lim: int = n;
                if mx >= 0 and pos + mx < n {
                    lim = pos + mx;
                }
                rp: int = pos;
                if kind == _O_CLASS {
                    cw: int = cbp + arg * 32;
                    while rp < lim {
                        c2: int = _cat(base, wide, rp);
                        if c2 < 128 {
                            if (
                                (int(__mem_load_i64(cw + (c2 >> 5) * 8)) >> (c2 & 31))
                                & 1
                            )
                                == 0 {
                                break;
                            }
                        } elif not _cls_wide_has(re, arg, c2) {
                            break;
                        }
                        rp += 1;
                    }
                } elif kind == _O_ANYALL {
                    rp = lim;
                } elif kind == _O_ANY {
                    if wide {
                        while rp < lim and _cat(base, wide, rp) != 10 {
                            rp += 1;
                        }
                    } elif rp < lim {
                        nl: int = memchr(base + rp, i32(10), u64(lim - rp));
                        rp = lim if nl == 0 else nl - base;
                    }
                } elif kind == _O_CHAR {
                    while rp < lim and _cat(base, wide, rp) == arg {
                        rp += 1;
                    }
                } else {
                    lc: int = arg & 2097151;
                    uc: int = arg >> 21;
                    while rp < lim {
                        c3: int = _cat(base, wide, rp);
                        if c3 != lc and c3 != uc {
                            break;
                        }
                        rp += 1;
                    }
                }
                if rp - pos >= mn {
                    if rp - pos > mn {
                        if sp + 4 > cap {
                            st.sp = sp;
                            sb = _grow(st, sp + 4);
                            cap = len(st.stk);
                        }
                        __mem_store_i64(sb + sp * 8, pc);
                        __mem_store_i64(sb + (sp + 1) * 8, rp);
                        __mem_store_i64(sb + (sp + 2) * 8, pos + mn);
                        __mem_store_i64(sb + (sp + 3) * 8, _T_REPG);
                        sp += 4;
                    }
                    pos = rp;
                    pc += 1;
                    continue;
                }
            } elif op == _O_SPLIT {
                if sp + 4 > cap {
                    st.sp = sp;
                    sb = _grow(st, sp + 4);
                    cap = len(st.stk);
                }
                __mem_store_i64(sb + sp * 8, __mem_load_i64(k + 16));
                __mem_store_i64(sb + (sp + 1) * 8, pos);
                __mem_store_i64(sb + (sp + 3) * 8, _T_SPLIT);
                sp += 4;
                pc = int(__mem_load_i64(k + 8));
                continue;
            } elif op == _O_JMP {
                pc = int(__mem_load_i64(k + 8));
                continue;
            } elif op == _O_SAVE {
                sl: int = int(__mem_load_i64(k + 8));
                if sp + 4 > cap {
                    st.sp = sp;
                    sb = _grow(st, sp + 4);
                    cap = len(st.stk);
                }
                __mem_store_i64(sb + sp * 8, sl);
                __mem_store_i64(sb + (sp + 1) * 8, __mem_load_i64(slp + sl * 8));
                __mem_store_i64(sb + (sp + 3) * 8, _T_SAVE);
                sp += 4;
                __mem_store_i64(slp + sl * 8, pos);
                pc += 1;
                continue;
            } elif op == _O_MATCH {
                if not top {
                    st.sp = sp;
                    return pos;
                }
                if pos != st.adv_pos and (not st.match_all or pos == n) {
                    res = pos;
                    sp = sp0;
                    break;
                }
            } elif op == _O_MARK {
                mk: int = int(__mem_load_i64(k + 8));
                if sp + 4 > cap {
                    st.sp = sp;
                    sb = _grow(st, sp + 4);
                    cap = len(st.stk);
                }
                __mem_store_i64(sb + sp * 8, mk);
                __mem_store_i64(sb + (sp + 1) * 8, __mem_load_i64(mkp + mk * 8));
                __mem_store_i64(sb + (sp + 3) * 8, _T_MARK);
                sp += 4;
                __mem_store_i64(mkp + mk * 8, pos);
                pc += 1;
                continue;
            } elif op == _O_JMPNZ {
                if int(__mem_load_i64(mkp + int(__mem_load_i64(k + 8)) * 8)) != pos {
                    pc = int(__mem_load_i64(k + 16));
                } else {
                    pc += 1;
                }
                continue;
            } elif op == _O_ANY {
                if pos < n and _cat(base, wide, pos) != 10 {
                    pos += 1;
                    pc += 1;
                    continue;
                }
            } elif op == _O_ANYALL {
                if pos < n {
                    pos += 1;
                    pc += 1;
                    continue;
                }
            } elif op == _O_CHAR2 {
                if pos < n {
                    c4: int = _cat(base, wide, pos);
                    if c4 == int(__mem_load_i64(k + 8))
                        or c4 == int(__mem_load_i64(k + 16)) {
                        pos += 1;
                        pc += 1;
                        continue;
                    }
                }
            } elif op == _O_REPL {
                kind2: int = int(__mem_load_i64(k + 8));
                arg2: int = int(__mem_load_i64(k + 16));
                mn2: int = int(__mem_load_i64(k + 24));
                mx2: int = int(__mem_load_i64(k + 32));
                q: int = pos;
                ok: bool = True;
                cnt: int = 0;
                while cnt < mn2 {
                    if q < n and _item_ok(re, kind2, arg2, _cat(base, wide, q)) {
                        q += 1;
                        cnt += 1;
                    } else {
                        ok = False;
                        break;
                    }
                }
                if ok {
                    zmax: int = n;
                    if mx2 >= 0 and pos + mx2 < n {
                        zmax = pos + mx2;
                    }
                    lit: int = int(__mem_load_i64(k + 40));
                    if lit >= 0
                        and not wide
                        and lit < 128
                        and kind2 == _O_ANY
                        and q < zmax {
                        hl: int = memchr(base + q, i32(lit), u64(zmax - q));
                        if hl == 0 {
                            hl = base + zmax;
                        }
                        nl2: int = 0;
                        if hl > base + q {
                            nl2 = memchr(base + q, i32(10), u64(hl - base - q));
                        }
                        if nl2 != 0 {
                            ok = False;
                        } else {
                            q = hl - base;
                        }
                    } elif lit >= 0 {
                        while q < zmax {
                            c5: int = _cat(base, wide, q);
                            if c5 == lit {
                                break;
                            }
                            if not _item_ok(re, kind2, arg2, c5) {
                                ok = False;
                                break;
                            }
                            q += 1;
                        }
                    }
                    if ok {
                        if q < zmax {
                            if sp + 4 > cap {
                                st.sp = sp;
                                sb = _grow(st, sp + 4);
                                cap = len(st.stk);
                            }
                            __mem_store_i64(sb + sp * 8, pc);
                            __mem_store_i64(sb + (sp + 1) * 8, q);
                            __mem_store_i64(sb + (sp + 2) * 8, zmax);
                            __mem_store_i64(sb + (sp + 3) * 8, _T_REPL);
                            sp += 4;
                        }
                        pos = q;
                        pc += 1;
                        continue;
                    }
                }
            } elif op == _O_BOS {
                if pos == 0 {
                    pc += 1;
                    continue;
                }
            } elif op == _O_BEGLINE {
                if pos == 0 or _cat(base, wide, pos - 1) == 10 {
                    pc += 1;
                    continue;
                }
            } elif op == _O_END {
                if pos == n or (pos == n - 1 and _cat(base, wide, pos) == 10) {
                    pc += 1;
                    continue;
                }
            } elif op == _O_ENDLINE {
                if pos == n or (pos < n and _cat(base, wide, pos) == 10) {
                    pc += 1;
                    continue;
                }
            } elif op == _O_EOS {
                if pos == n {
                    pc += 1;
                    continue;
                }
            } elif op == _O_WB or op == _O_NWB {
                lft: bool = pos > 0 and is_word(_cat(base, wide, pos - 1));
                rgt: bool = pos < n and is_word(_cat(base, wide, pos));
                if (lft != rgt) == (op == _O_WB) {
                    pc += 1;
                    continue;
                }
            } elif op == _O_BACKREF or op == _O_BACKREFI {
                g: int = int(__mem_load_i64(k + 8)) * 2;
                glo: int = int(__mem_load_i64(slp + g * 8));
                ghi: int = int(__mem_load_i64(slp + (g + 1) * 8));
                if glo >= 0 and ghi >= glo {
                    ln: int = ghi - glo;
                    if pos + ln <= n {
                        j: int = 0;
                        same: bool = True;
                        while j < ln {
                            ga: int = _cat(base, wide, glo + j);
                            gb: int = _cat(base, wide, pos + j);
                            if ga != gb and (op == _O_BACKREF or swapcase(ga) != gb) {
                                same = False;
                                break;
                            }
                            j += 1;
                        }
                        if same {
                            pos += ln;
                            pc += 1;
                            continue;
                        }
                    }
                }
            } elif op == _O_LOOK {
                st.sp = sp;
                r4: int = _exec(re, st, int(__mem_load_i64(k + 8)), pos, 0);
                neg: bool = int(__mem_load_i64(k + 16)) != 0;
                if r4 >= 0 {
                    _unwind(st, sp, not neg);
                }
                sp = st.sp;
                sb = __list_data_ptr(st.stk);
                cap = len(st.stk);
                if (r4 >= 0) != neg {
                    pc += 1;
                    continue;
                }
            }
            found: bool = False;
            while sp > sp0 {
                sp -= 4;
                tag: int = int(__mem_load_i64(sb + (sp + 3) * 8));
                x: int = int(__mem_load_i64(sb + sp * 8));
                y: int = int(__mem_load_i64(sb + (sp + 1) * 8));
                if tag == _T_SPLIT {
                    pc = x;
                    pos = y;
                    found = True;
                    break;
                }
                if tag == _T_SAVE {
                    __mem_store_i64(slp + x * 8, y);
                    continue;
                }
                z: int = int(__mem_load_i64(sb + (sp + 2) * 8));
                if tag == _T_REPG {
                    b: int = y - 1;
                    flit: int = int(__mem_load_i64(pb + x * 48 + 40));
                    if flit >= 0 {
                        while b >= z and _cat(base, wide, b) != flit {
                            b -= 1;
                        }
                    }
                    if b < z {
                        continue;
                    }
                    if b > z {
                        __mem_store_i64(sb + (sp + 1) * 8, b);
                        sp += 4;
                    }
                    pc = x + 1;
                    pos = b;
                    found = True;
                    break;
                }
                if tag == _T_MARK {
                    __mem_store_i64(mkp + x * 8, y);
                    continue;
                }
                if tag == _T_REPL {
                    rk: int = pb + x * 48;
                    rkind: int = int(__mem_load_i64(rk + 8));
                    rarg: int = int(__mem_load_i64(rk + 16));
                    e: int = y;
                    if e < z and _item_ok(re, rkind, rarg, _cat(base, wide, e)) {
                        e += 1;
                        good: bool = True;
                        llit: int = int(__mem_load_i64(rk + 40));
                        if llit >= 0 {
                            while e < z {
                                c6: int = _cat(base, wide, e);
                                if c6 == llit {
                                    break;
                                }
                                if not _item_ok(re, rkind, rarg, c6) {
                                    good = False;
                                    break;
                                }
                                e += 1;
                            }
                        }
                        if good {
                            if e < z {
                                __mem_store_i64(sb + (sp + 1) * 8, e);
                                sp += 4;
                            }
                            pc = x + 1;
                            pos = e;
                            found = True;
                            break;
                        }
                    }
                    continue;
                }
            }
            if not found {
                sp = sp0;
                break;
            }
        }
        if res >= 0 {
            if top {
                __mem_store_i64(slp, p);
                __mem_store_i64(slp + 8, res);
            }
            st.sp = sp0;
            return res;
        }
        if mode != 2 {
            st.sp = sp0;
            return -1;
        }
        p += 1;
    }
    return -1;
}


impl Match.init(
    _re: _Re, string: str, pos: int, endpos: int, s0: int, e0: int, slots: list[int]
) {
    self._re = _re;
    self.string = string;
    self.pos = pos;
    self.endpos = endpos;
    self._s0 = s0;
    self._e0 = e0;
    self._slots = slots;
}

impl Match._lo(g: int) -> int {
    if g == 0 {
        return self._s0;
    }
    return self._slots[g * 2];
}

impl Match._hi(g: int) -> int {
    if g == 0 {
        return self._e0;
    }
    return self._slots[g * 2 + 1];
}

impl Match._gtext(num: int) -> str {
    lo: int = self._lo(num);
    hi: int = self._hi(num);
    if lo < 0 or hi < lo {
        return "";
    }
    return self.string[lo:hi];
}

impl Match._gnum(i: (int | str)) -> int {
    if isinstance(i, int) {
        iv: int = i;
        if iv < 0 or iv > self._re.ngroups {
            raise IndexError("no such group");
        }
        return iv;
    }
    sv: str = i;
    gn: int = _name_index(self._re.names, sv);
    if gn >= 0 {
        return gn;
    }
    raise IndexError("no such group");
}

impl Match.group(i: (int | str) = 0) -> any {
    g: int = self._gnum(i);
    lo: int = self._lo(g);
    hi: int = self._hi(g);
    if lo < 0 or hi < lo {
        return None;
    }
    return self.string[lo:hi];
}

impl Match.groups(`default: any = None) -> list[any] {
    out: list[any] = [];
    g: int = 1;
    while g <= self._re.ngroups {
        lo: int = self._slots[g * 2];
        hi: int = self._slots[g * 2 + 1];
        if lo < 0 or hi < lo {
            out.append(`default);
        } else {
            out.append(self.string[lo:hi]);
        }
        g += 1;
    }
    return out;
}

impl Match.groupdict(`default: any = None) -> dict[str, any] {
    out: dict[str, any] = {};
    for nm in self._re.names {
        g: int = self._re.names[nm];
        lo: int = self._slots[g * 2];
        hi: int = self._slots[g * 2 + 1];
        if lo < 0 or hi < lo {
            out[nm] = `default;
        } else {
            out[nm] = self.string[lo:hi];
        }
    }
    return out;
}

impl Match.start(i: (int | str) = 0) -> int {
    g: int = self._gnum(i);
    if g == 0 {
        return self._s0;
    }
    return self._slots[g * 2];
}

impl Match.end(i: (int | str) = 0) -> int {
    g: int = self._gnum(i);
    if g == 0 {
        return self._e0;
    }
    return self._slots[g * 2 + 1];
}

impl Match.span(i: (int | str) = 0) -> tuple[(int, int)] {
    g: int = self._gnum(i);
    return (self._lo(g), self._hi(g));
}

impl Match.expand(template: str) -> str {
    rp: _Repl = _compile_repl(template, self._re);
    return _apply_repl(rp, self.string, self._s0, self._e0, self._slots);
}


impl Pattern.init(pattern: str, flags: int = 0) {
    self.pattern = pattern;
    self._re = _compile_re(pattern, flags);
    pf: int = self._re.flags;
    if (pf & ASCII) == 0 {
        pf = pf | UNICODE;
    }
    self.flags = pf;
    self.groups = self._re.ngroups;
    self.groupindex = self._re.names;
    self._st = _new_st(self._re);
    self._lk = [0];
    self._lock = __list_data_ptr(self._lk);
}

impl _hit(re: _Re, st: _St, string: str, b0: int, b1: int) -> Match {
    if re.ngroups == 0 {
        return Match(re, string, b0, b1, st.slots[0], st.slots[1], re.empty);
    }
    m: Match = Match(re, string, b0, b1, st.slots[0], st.slots[1], st.slots[:]);
    i: int = 0;
    n: int = len(st.slots);
    while i < n {
        st.slots[i] = -1;
        i += 1;
    }
    return m;
}


impl _one(
    re: _Re, st: _St, string: str, pos: int, endpos: int, mode: int
) -> (Match | None) {
    sn: int = len(string);
    b0: int = pos;
    if b0 < 0 {
        b0 = 0;
    } elif b0 > sn {
        b0 = sn;
    }
    b1: int = endpos;
    if b1 < 0 {
        b1 = 0;
    } elif b1 > sn {
        b1 = sn;
    }
    if b0 > b1 {
        return None;
    }
    if string.isascii() {
        st.wide = False;
        st.base = __str_data(string);
    } else {
        _prep(st, string, b1);
    }
    st.n = b1;
    st.adv_pos = -1;
    st.match_all = mode == 2;
    r: int = -1;
    if mode == 0 {
        r = _exec(re, st, 0, b0, 2);
    } else {
        r = _exec(re, st, 0, b0, 1);
    }
    st.match_all = False;
    if r < 0 {
        return None;
    }
    if re.ngroups == 0 {
        return Match(re, string, b0, b1, st.slots[0], r, re.empty);
    }
    return _hit(re, st, string, b0, b1);
}


impl _iter(re: _Re, st: _St, string: str, pos: int, endpos: int) -> list[Match] {
    out: list[Match] = [];
    sn: int = len(string);
    b0: int = _clamp(pos, sn);
    b1: int = _clamp(endpos, sn);
    if b0 > b1 {
        return out;
    }
    _prep(st, string, b1);
    p: int = b0;
    while True {
        r: int = _exec(re, st, 0, p, 2);
        if r < 0 {
            break;
        }
        s0: int = st.slots[0];
        out.append(_hit(re, st, string, b0, b1));
        st.adv_pos = r if r == s0 else -1;
        p = r;
    }
    return out;
}


impl _all(re: _Re, st: _St, string: str, pos: int, endpos: int) -> list[str] {
    out: list[str] = [];
    sn: int = len(string);
    b0: int = _clamp(pos, sn);
    b1: int = _clamp(endpos, sn);
    if b0 > b1 {
        return out;
    }
    _prep(st, string, b1);
    p: int = b0;
    while True {
        r: int = _exec(re, st, 0, p, 2);
        if r < 0 {
            break;
        }
        s0: int = st.slots[0];
        if re.ngroups == 0 {
            out.append(string[s0:r]);
        } else {
            lo: int = st.slots[2];
            hi: int = st.slots[3];
            if lo < 0 or hi < lo {
                out.append("");
            } else {
                out.append(string[lo:hi]);
            }
            st.slots[2] = -1;
            st.slots[3] = -1;
        }
        st.adv_pos = r if r == s0 else -1;
        p = r;
    }
    return out;
}


impl _split(re: _Re, st: _St, string: str, maxsplit: int) -> list[any] {
    n: int = len(string);
    out: list[any] = [];
    _prep(st, string, n);
    ng: int = re.ngroups;
    last: int = 0;
    count: int = 0;
    p: int = 0;
    while maxsplit == 0 or count < maxsplit {
        r: int = _exec(re, st, 0, p, 2);
        if r < 0 {
            break;
        }
        s0: int = st.slots[0];
        out.append(string[last:s0]);
        g: int = 1;
        while g <= ng {
            lo: int = st.slots[g * 2];
            hi: int = st.slots[g * 2 + 1];
            if lo < 0 or hi < lo {
                out.append(None);
            } else {
                out.append(string[lo:hi]);
            }
            st.slots[g * 2] = -1;
            st.slots[g * 2 + 1] = -1;
            g += 1;
        }
        count += 1;
        st.adv_pos = r if r == s0 else -1;
        last = r;
        p = r;
    }
    out.append(string[last:n]);
    return out;
}


impl _subn_core(
    re: _Re, st: _St, rp: _Repl, string: str, count: int
) -> tuple[(str, int)] {
    n: int = len(string);
    _prep(st, string, n);
    ng: int = re.ngroups;
    out: str = "";
    last: int = 0;
    nsub: int = 0;
    p: int = 0;
    while count == 0 or nsub < count {
        r: int = _exec(re, st, 0, p, 2);
        if r < 0 {
            break;
        }
        s0: int = st.slots[0];
        if last < s0 {
            out += string[last:s0];
        }
        if rp.literal {
            out += rp.lits[0];
        } else {
            out += _apply_repl(rp, string, s0, r, st.slots);
        }
        if ng > 0 {
            g: int = 2;
            while g < (ng + 1) * 2 {
                st.slots[g] = -1;
                g += 1;
            }
        }
        nsub += 1;
        st.adv_pos = r if r == s0 else -1;
        last = r;
        p = r;
    }
    if nsub == 0 {
        return (string, 0);
    }
    if last < n {
        out += string[last:n];
    }
    return (out, nsub);
}


impl Pattern._acquire -> bool {
    return __atomic_xchg_i64(self._lock, 1) == 0;
}

impl Pattern._release {
    __atomic_xchg_i64(self._lock, 0);
}

impl Pattern.search(
    string: str, pos: int = 0, endpos: int = _MAXPOS
) -> (Match | None) {
    if __atomic_xchg_i64(self._lock, 1) != 0 {
        return _one(self._re, _new_st(self._re), string, pos, endpos, 0);
    }
    sn: int = len(string);
    b0: int = pos;
    if b0 < 0 {
        b0 = 0;
    } elif b0 > sn {
        b0 = sn;
    }
    b1: int = endpos;
    if b1 < 0 {
        b1 = 0;
    } elif b1 > sn {
        b1 = sn;
    }
    if b0 > b1 {
        __atomic_xchg_i64(self._lock, 0);
        return None;
    }
    if string.isascii() {
        self._st.wide = False;
        self._st.base = __str_data(string);
    } else {
        _prep(self._st, string, b1);
    }
    self._st.n = b1;
    self._st.adv_pos = -1;
    r: int = _exec(self._re, self._st, 0, b0, 2);
    m: (Match | None) = None;
    if r >= 0 {
        if self._re.ngroups == 0 {
            m = Match(self._re, string, b0, b1, self._st.slots[0], r, self._re.empty);
        } else {
            m = _hit(self._re, self._st, string, b0, b1);
        }
    }
    __atomic_xchg_i64(self._lock, 0);
    return m;
}

impl Pattern.`match(
    string: str, pos: int = 0, endpos: int = _MAXPOS
) -> (Match | None) {
    if __atomic_xchg_i64(self._lock, 1) == 0 {
        m: (Match | None) = _one(self._re, self._st, string, pos, endpos, 1);
        __atomic_xchg_i64(self._lock, 0);
        return m;
    }
    return _one(self._re, _new_st(self._re), string, pos, endpos, 1);
}

impl Pattern.fullmatch(
    string: str, pos: int = 0, endpos: int = _MAXPOS
) -> (Match | None) {
    if __atomic_xchg_i64(self._lock, 1) == 0 {
        m: (Match | None) = _one(self._re, self._st, string, pos, endpos, 2);
        __atomic_xchg_i64(self._lock, 0);
        return m;
    }
    return _one(self._re, _new_st(self._re), string, pos, endpos, 2);
}

impl Pattern.finditer(string: str, pos: int = 0, endpos: int = _MAXPOS) -> list[Match] {
    if self._acquire() {
        out: list[Match] = _iter(self._re, self._st, string, pos, endpos);
        self._release();
        return out;
    }
    return _iter(self._re, _new_st(self._re), string, pos, endpos);
}

impl Pattern.findall(string: str, pos: int = 0, endpos: int = _MAXPOS) -> list[str] {
    if self._re.ngroups > 1 {
        raise ValueError(
            "findall: patterns with more than one group are not supported on native"
        );
    }
    if self._acquire() {
        out: list[str] = _all(self._re, self._st, string, pos, endpos);
        self._release();
        return out;
    }
    return _all(self._re, _new_st(self._re), string, pos, endpos);
}

impl Pattern.split(string: str, maxsplit: int = 0) -> list[any] {
    if self._acquire() {
        out: list[any] = _split(self._re, self._st, string, maxsplit);
        self._release();
        return out;
    }
    return _split(self._re, _new_st(self._re), string, maxsplit);
}

impl Pattern._subn(repl: str, string: str, count: int) -> tuple[(str, int)] {
    rp: _Repl = _compile_repl(repl, self._re);
    if self._acquire() {
        res: tuple[(str, int)] = _subn_core(self._re, self._st, rp, string, count);
        self._release();
        return res;
    }
    return _subn_core(self._re, _new_st(self._re), rp, string, count);
}

impl Pattern.sub(repl: str, string: str, count: int = 0) -> str {
    r: tuple[(str, int)] = self._subn(repl, string, count);
    return r[0];
}

impl Pattern.subn(repl: str, string: str, count: int = 0) -> tuple[(str, int)] {
    return self._subn(repl, string, count);
}


impl _compile_re(pattern: str, flags: int) -> _Re {
    p: _P = _P();
    p.cps = utf8_cps(pattern.encode());
    p.n = len(p.cps);
    p.flags = flags;
    tree: _Node = p._parse();
    re: _Re = _Re();
    re.ngroups = p.ngroups;
    re.names = p.names;
    re.flags = p.flags;
    re.pattern = pattern;
    re.prog = [];
    re.cbits = [];
    re.classes = [];
    re.empty = [];
    _compile_node(tree, re, p.flags);
    _emit(re, _O_MATCH, 0, 0, 0, 0);
    ni: int = len(re.prog) // 6;
    i: int = 0;
    while i < ni {
        if re.prog[i * 6] == _O_REPG or re.prog[i * 6] == _O_REPL {
            j: int = i + 1;
            while j < ni and re.prog[j * 6] == _O_SAVE {
                j += 1;
            }
            if j < ni and re.prog[j * 6] == _O_CHAR {
                re.prog[i * 6 + 5] = re.prog[j * 6 + 1];
            }
        }
        i += 1;
    }
    _analyze(tree, re);
    return re;
}


impl _cache_lock {
    lk: int = __list_data_ptr(_CLK);
    while __atomic_xchg_i64(lk, 1) != 0 {
        sched_yield();
    }
}


impl _cache_unlock {
    __atomic_xchg_i64(__list_data_ptr(_CLK), 0);
}


impl _cached(pattern: str, flags: int) -> Pattern {
    key: str = pattern;
    if flags != 0 {
        key = str(flags) + "\x00" + pattern;
    }
    _cache_lock();
    if flags == 0 {
        if pattern in _CACHE {
            hit: Pattern = _CACHE[pattern];
            _cache_unlock();
            return hit;
        }
    } elif key in _CACHEF {
        hitf: Pattern = _CACHEF[key];
        _cache_unlock();
        return hitf;
    }
    _cache_unlock();
    p: Pattern = Pattern(pattern, flags);
    _cache_lock();
    if flags == 0 {
        if len(_CACHE) >= _MAXCACHE {
            _CACHE.clear();
        }
        _CACHE[pattern] = p;
    } else {
        if len(_CACHEF) >= _MAXCACHE {
            _CACHEF.clear();
        }
        _CACHEF[key] = p;
    }
    _cache_unlock();
    return p;
}


impl _compile_repl(template: str, re: _Re) -> _Repl {
    rp: _Repl = _Repl();
    rp.lits = [];
    rp.grps = [];
    if "\\" not in template {
        rp.lits.append(template);
        return rp;
    }
    rp.literal = False;
    tps: list[int] = utf8_cps(template.encode());
    n: int = len(tps);
    out: str = "";
    i: int = 0;
    while i < n {
        c: int = tps[i];
        if c != 92 {
            out += chr(c);
            i += 1;
            continue;
        }
        bp: int = i;
        if i + 1 >= n {
            raise ValueError("bad escape (end of pattern) at position " + str(n - 1));
        }
        e: int = tps[i + 1];
        i += 2;
        if e == 103 {
            if i >= n or tps[i] != 60 {
                raise ValueError("missing < at position " + str(i));
            }
            i += 1;
            nm: str = "";
            nlen: int = 0;
            while True {
                if i >= n {
                    if nlen == 0 {
                        raise ValueError("missing group name at position " + str(n));
                    }
                    raise ValueError(
                        "missing >, unterminated name at position " + str(n - nlen)
                    );
                }
                t: int = tps[i];
                if t == 92 {
                    if i + 1 >= n {
                        raise ValueError(
                            "bad escape (end of pattern) at position " + str(n - 1)
                        );
                    }
                    nm += chr(t) + chr(tps[i + 1]);
                    nlen += 2;
                    i += 2;
                    continue;
                }
                i += 1;
                if t == 62 {
                    if nlen == 0 {
                        raise ValueError(
                            "missing group name at position " + str(i - 1)
                        );
                    }
                    break;
                }
                nm += chr(t);
                nlen += 1;
            }
            npos: int = i - (nlen + 1);
            alldig: bool = True;
            ident: bool = True;
            k: int = i - 1 - nlen;
            j: int = 0;
            while j < nlen {
                cc: int = tps[k + j];
                if not is_digit(cc) {
                    alldig = False;
                }
                if cc < 128 and (not is_word(cc) or (j == 0 and is_digit(cc))) {
                    ident = False;
                }
                j += 1;
            }
            num: int = 0;
            if alldig {
                j = 0;
                while j < nlen {
                    num = num * 10 + (tps[k + j] - 48);
                    j += 1;
                }
            } else {
                if not ident {
                    raise ValueError(
                        "bad character in group name '"
                            + nm
                            + "' at position "
                            + str(npos)
                    );
                }
                num = _name_index(re.names, nm);
                if num < 0 {
                    raise IndexError("unknown group name '" + nm + "'");
                }
            }
            if num > re.ngroups {
                raise ValueError(
                    "invalid group reference " + str(num) + " at position " + str(npos)
                );
            }
            rp.lits.append(out);
            rp.grps.append(num);
            out = "";
            continue;
        }
        if e == 48 {
            v: int = 0;
            cnt: int = 0;
            while cnt < 2 and i < n and tps[i] >= 48 and tps[i] <= 55 {
                v = v * 8 + (tps[i] - 48);
                i += 1;
                cnt += 1;
            }
            out += chr(v & 255);
            continue;
        }
        if e >= 49 and e <= 57 {
            gnum: int = e - 48;
            octal: bool = False;
            if i < n and is_digit(tps[i]) {
                d2: int = tps[i];
                i += 1;
                if e <= 55 and d2 <= 55 and i < n and tps[i] >= 48 and tps[i] <= 55 {
                    d3: int = tps[i];
                    i += 1;
                    ov: int = (e - 48) * 64 + (d2 - 48) * 8 + (d3 - 48);
                    if ov > 255 {
                        raise ValueError(
                            "octal escape value \\"
                                + chr(e)
                                + chr(d2)
                                + chr(d3)
                                + " outside of range 0-0o377 at position "
                                + str(bp)
                        );
                    }
                    out += chr(ov);
                    octal = True;
                } else {
                    gnum = gnum * 10 + (d2 - 48);
                }
            }
            if not octal {
                if gnum > re.ngroups {
                    raise ValueError(
                        "invalid group reference "
                            + str(gnum)
                            + " at position "
                            + str(bp + 1)
                    );
                }
                rp.lits.append(out);
                rp.grps.append(gnum);
                out = "";
            }
            continue;
        }
        if e == 97 {
            out += "\x07";
        } elif e == 98 {
            out += "\x08";
        } elif e == 102 {
            out += "\x0c";
        } elif e == 110 {
            out += "\n";
        } elif e == 114 {
            out += "\r";
        } elif e == 116 {
            out += "\t";
        } elif e == 118 {
            out += "\x0b";
        } elif e == 92 {
            out += "\\";
        } elif is_alpha(e) {
            raise ValueError("bad escape \\" + chr(e) + " at position " + str(bp));
        } else {
            out += "\\" + chr(e);
        }
    }
    rp.lits.append(out);
    return rp;
}


impl _apply_repl(rp: _Repl, string: str, s0: int, e0: int, slots: list[int]) -> str {
    out: str = rp.lits[0];
    i: int = 0;
    n: int = len(rp.grps);
    while i < n {
        g: int = rp.grps[i];
        lo: int = s0;
        hi: int = e0;
        if g > 0 {
            lo = slots[g * 2];
            hi = slots[g * 2 + 1];
        }
        if lo >= 0 and hi >= lo {
            out += string[lo:hi];
        }
        out += rp.lits[i + 1];
        i += 1;
    }
    return out;
}


impl compile(pattern: str, flags: int = 0) -> Pattern {
    return _cached(pattern, flags);
}


impl search(pattern: str, string: str, flags: int = 0) -> (Match | None) {
    return _cached(pattern, flags).search(string);
}


impl `match(pattern: str, string: str, flags: int = 0) -> (Match | None) {
    return _cached(pattern, flags).`match(string);
}


impl fullmatch(pattern: str, string: str, flags: int = 0) -> (Match | None) {
    return _cached(pattern, flags).fullmatch(string);
}


impl findall(pattern: str, string: str, flags: int = 0) -> list[str] {
    return _cached(pattern, flags).findall(string);
}


impl finditer(pattern: str, string: str, flags: int = 0) -> list[Match] {
    return _cached(pattern, flags).finditer(string);
}


impl split(pattern: str, string: str, maxsplit: int = 0, flags: int = 0) -> list[any] {
    return _cached(pattern, flags).split(string, maxsplit);
}


impl sub(pattern: str, repl: str, string: str, count: int = 0, flags: int = 0) -> str {
    return _cached(pattern, flags).sub(repl, string, count);
}


impl subn(
    pattern: str, repl: str, string: str, count: int = 0, flags: int = 0
) -> tuple[(str, int)] {
    return _cached(pattern, flags).subn(repl, string, count);
}


impl escape(pattern: str) -> str {
    out: str = "";
    i: int = 0;
    n: int = len(pattern);
    while i < n {
        ch: str = pattern[i];
        if ch in _ESCAPE_SPECIAL {
            out += "\\";
        }
        out += ch;
        i += 1;
    }
    return out;
}


impl purge {
    _cache_lock();
    _CACHE.clear();
    _CACHEF.clear();
    _cache_unlock();
}
