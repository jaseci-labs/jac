glob:pub I: int = 2,
     IGNORECASE: int = 2,
     L: int = 4,
     LOCALE: int = 4,
     M: int = 8,
     MULTILINE: int = 8,
     S: int = 16,
     DOTALL: int = 16,
     U: int = 32,
     UNICODE: int = 32,
     X: int = 64,
     VERBOSE: int = 64,
     A: int = 256,
     ASCII: int = 256,
     T: int = 1,
     TEMPLATE: int = 1;

enum _K: int {
    SEQ = 1,
    ALT = 2,
    CHAR = 3,
    ANY = 4,
    CLASS = 5,
    AT = 6,
    GROUP = 7,
    REP = 8,
    BACKREF = 9,
    LOOK = 10,
    FLAGS = 11
}


enum _AT: int {
    BOS = 1,
    BEG = 2,
    BEGLINE = 3,
    EOS = 4,
    END = 5,
    ENDLINE = 6,
    WB = 7,
    WNB = 8
}


enum _OP: int {
    CHAR = 1,
    ANY = 2,
    CLASS = 3,
    SPLIT = 4,
    JMP = 5,
    MARK = 6,
    JMPNZ = 7,
    SAVE = 8,
    MATCH = 9,
    BOS = 10,
    BEGLINE = 11,
    END = 12,
    ENDLINE = 13,
    EOS = 14,
    WB = 15,
    BACKREF = 16,
    FPUSH = 17,
    FPOP = 18,
    LOOK = 19
}


glob _BT_SPLIT: int = 1,
     _BT_SAVE: int = 2,
     _BT_MARK: int = 3,
     _BT_FPUSH: int = 4,
     _BT_FPOP: int = 5;

glob _MAXCP: int = 1114111;

glob _MAXPOS: int = 9223372036854775807;

glob _ESCAPE_SPECIAL: str = "()[]{}?*+-|^$\\.&~# \t\n\r\x0b\x0c";

glob _DIGIT_PRS: list[int] = [48, 57],
     _NDIGIT_PRS: list[int] = [0, 47, 58, 1114111],
     _SPACE_PRS: list[int] = [9, 13, 32, 32],
     _NSPACE_PRS: list[int] = [0, 8, 14, 31, 33, 1114111],
     _WORD_PRS: list[int] = [48, 57, 65, 90, 95, 95, 97, 122],
     _NWORD_PRS: list[int] = [0, 47, 58, 64, 91, 94, 96, 96, 123, 1114111];

import from _re_posix_native {
    posix_probe,
    posix_compile,
    posix_exec,
    posix_free,
    pm_off
}

import from _ascii { is_digit, is_word, is_alpha, is_space, swapcase, hexv }
import from _utf8 { utf8_cps, cp_off, cp_len, cps_str, cpslice_str, is_ascii }


obj _PS {
    has gen: int = 0,
        pregs: list[bytes] = [];
}


glob _PMW: int = posix_probe(),
     _PSX: _PS = _PS();


def _push_prs(dst: list[int], src: list[int]) {
    k: int = 0;
    while k < len(src) {
        dst.append(src[k]);
        k += 1;
    }
}


def _in_pairs(pairs: list[int], c: int) -> bool {
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


def _name_index(names: dict[str, int], nm: str) -> int {
    if nm in names {
        return names[nm];
    }
    return -1;
}


def _num_esc(cps: list[int], i: int, e: int, bp: int) -> tuple[(int, int)] {
    n: int = len(cps);
    if e == 120 {
        if i + 1 >= n {
            raise ValueError("bad escape \\x at position " + str(bp));
        }
        h1: int = hexv(cps[i]);
        h2: int = hexv(cps[i + 1]);
        if h1 < 0 or h2 < 0 {
            raise ValueError("bad escape \\x at position " + str(bp));
        }
        return (h1 * 16 + h2, i + 2);
    }
    if e == 117 {
        if i + 3 >= n {
            raise ValueError("bad escape \\u at position " + str(bp));
        }
        v: int = 0;
        k: int = 0;
        while k < 4 {
            hv: int = hexv(cps[i + k]);
            if hv < 0 {
                raise ValueError("bad escape \\u at position " + str(bp));
            }
            v = v * 16 + hv;
            k += 1;
        }
        return (v, i + 4);
    }
    if e == 85 {
        if i + 7 >= n {
            raise ValueError("bad escape \\U at position " + str(bp));
        }
        v = 0;
        k = 0;
        while k < 8 {
            hv = hexv(cps[i + k]);
            if hv < 0 {
                raise ValueError("bad escape \\U at position " + str(bp));
            }
            v = v * 16 + hv;
            k += 1;
        }
        return (v, i + 8);
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
    return (v & _MAXCP, i);
}


def _bounds(n: int, pos: int, endpos: int) -> tuple[(int, int)] {
    if endpos < 0 {
        endpos = 0;
    }
    if endpos > n {
        endpos = n;
    }
    if pos < 0 {
        pos += n;
        if pos < 0 {
            pos = 0;
        }
    }
    if pos > n {
        pos = n;
    }
    return (pos, endpos);
}


obj _Node {
    has kind: _K = _K.SEQ,
        ch: int = 0,
        at: _AT = _AT.BOS,
        lo: int = 0,
        hi: int = -1,
        neg: bool = False,
        greedy: bool = True,
        pairs: list[int] = [],
        kids: list[_Node] = [],
        name: str = "";
}


obj _Ins {
    has op: _OP = _OP.CHAR,
        a: int = 0,
        b: int = 0;
}


obj _Cls {
    has pairs: list[int] = [],
        neg: bool = False;
}


obj _P {
    has cps: list[int] = [],
        n: int = 0,
        i: int = 0,
        flags: int = 0,
        ngroups: int = 0,
        names: dict[str, int] = {},
        pending: list[int] = [],
        pendingpos: list[int] = [],
        opengroups: list[int] = [],
        depth: int = 0,
        top_items: int = 0;

    def _err(msg: str, pos: int) {
        raise ValueError(msg + " at position " + str(pos));
    }

    def _skip_verbose {
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

    def _is_repeat_spec(pos: int) -> bool {
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

    def _rep_spec(pos: int) -> list[int] {
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
            self._err("min repeat greater than max repeat", pos);
        }
        return [lo, hi];
    }

    def _atom -> (_Node | None) {
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

    def _piece -> (_Node | None) {
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

    def _seq -> _Node {
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

    def _alt -> _Node {
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

    def _expect_close(open_pos: int) {
        if self.i >= self.n or self.cps[self.i] != 41 {
            self._err("missing ), unterminated subpattern", open_pos);
        }
        self.i += 1;
    }

    def _flagval(c: int) -> int {
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

    def _group -> (_Node | None) {
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

    def _class_item(pairs: list[int]) -> int {
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

    def _class -> _Node {
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
                        self._err(
                            "bad character range " + chr(lo) + "-" + chr(hi), lo_pos
                        );
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

    def _escape_atom -> _Node {
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
            while self.i < self.n and is_digit(self.cps[self.i]) {
                num = num * 10 + (self.cps[self.i] - 48);
                self.i += 1;
            }
            og: int = 0;
            while og < len(self.opengroups) {
                if self.opengroups[og] == num {
                    self._err("cannot refer to an open group", bp);
                }
                og += 1;
            }
            self.pending.append(num);
            self.pendingpos.append(bp);
            nd.kind = _K.BACKREF;
            nd.lo = num;
            return nd;
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

    def _parse -> _Node {
        nd: _Node = self._alt();
        if self.i < self.n {
            self._err("unbalanced parenthesis", self.i);
        }
        k: int = 0;
        while k < len(self.pending) {
            if self.pending[k] > self.ngroups {
                self._err(
                    "invalid group reference " + str(self.pending[k]),
                    self.pendingpos[k]
                );
            }
            k += 1;
        }
        return nd;
    }
}


obj _C {
    has prog: list[_Ins] = [],
        classes: list[_Cls] = [],
        nmarks: int = 0;
}


def _emit(c: _C, op: _OP, a: int, b: int) -> int {
    ins: _Ins = _Ins();
    ins.op = op;
    ins.a = a;
    ins.b = b;
    c.prog.append(ins);
    return len(c.prog) - 1;
}


def _compile_node(nd: _Node, c: _C) {
    kind: _K = nd.kind;
    if kind == _K.SEQ {
        i: int = 0;
        while i < len(nd.kids) {
            _compile_node(nd.kids[i], c);
            i += 1;
        }
        return;
    }
    if kind == _K.ALT {
        splits: list[int] = [];
        jmps: list[int] = [];
        last: int = len(nd.kids) - 1;
        j: int = 0;
        while j < last {
            si: int = _emit(c, _OP.SPLIT, len(c.prog) + 1, 0);
            splits.append(si);
            _compile_node(nd.kids[j], c);
            ji: int = _emit(c, _OP.JMP, 0, 0);
            jmps.append(ji);
            j += 1;
        }
        last_start: int = len(c.prog);
        _compile_node(nd.kids[last], c);
        e: int = len(c.prog);
        k: int = 0;
        while k < len(splits) {
            sins: _Ins = c.prog[splits[k]];
            if k + 1 < len(splits) {
                sins.b = splits[k + 1];
            } else {
                sins.b = last_start;
            }
            k += 1;
        }
        k = 0;
        while k < len(jmps) {
            jins: _Ins = c.prog[jmps[k]];
            jins.a = e;
            k += 1;
        }
        return;
    }
    if kind == _K.CHAR {
        _emit(c, _OP.CHAR, nd.ch, 0);
        return;
    }
    if kind == _K.ANY {
        _emit(c, _OP.ANY, 0, 0);
        return;
    }
    if kind == _K.CLASS {
        cl: _Cls = _Cls();
        cl.pairs = nd.pairs;
        cl.neg = nd.neg;
        c.classes.append(cl);
        _emit(c, _OP.CLASS, len(c.classes) - 1, 0);
        return;
    }
    if kind == _K.AT {
        op: _OP = _OP.BOS;
        if nd.at == _AT.BEGLINE {
            op = _OP.BEGLINE;
        } elif nd.at == _AT.END {
            op = _OP.END;
        } elif nd.at == _AT.ENDLINE {
            op = _OP.ENDLINE;
        } elif nd.at == _AT.EOS {
            op = _OP.EOS;
        } elif nd.at == _AT.WB {
            _emit(c, _OP.WB, 0, 0);
            return;
        } elif nd.at == _AT.WNB {
            _emit(c, _OP.WB, 1, 0);
            return;
        }
        _emit(c, op, 0, 0);
        return;
    }
    if kind == _K.GROUP {
        _emit(c, _OP.SAVE, nd.lo * 2, 0);
        _compile_node(nd.kids[0], c);
        _emit(c, _OP.SAVE, nd.lo * 2 + 1, 0);
        return;
    }
    if kind == _K.REP {
        kid: _Node = nd.kids[0];
        m: int = 0;
        while m < nd.lo {
            _compile_node(kid, c);
            m += 1;
        }
        if nd.hi < 0 {
            lpos: int = len(c.prog);
            si: int = 0;
            if nd.greedy {
                si = _emit(c, _OP.SPLIT, lpos + 1, 0);
            } else {
                si = _emit(c, _OP.SPLIT, 0, lpos + 1);
            }
            mark: int = c.nmarks;
            c.nmarks += 1;
            _emit(c, _OP.MARK, mark, 0);
            _compile_node(kid, c);
            _emit(c, _OP.JMPNZ, mark, lpos);
            epos: int = len(c.prog);
            tins: _Ins = c.prog[si];
            if nd.greedy {
                tins.b = epos;
            } else {
                tins.a = epos;
            }
            return;
        }
        splits: list[int] = [];
        j: int = nd.lo;
        while j < nd.hi {
            si2: int = 0;
            if nd.greedy {
                si2 = _emit(c, _OP.SPLIT, len(c.prog) + 1, 0);
            } else {
                si2 = _emit(c, _OP.SPLIT, 0, len(c.prog) + 1);
            }
            splits.append(si2);
            _compile_node(kid, c);
            j += 1;
        }
        epos = len(c.prog);
        k = 0;
        while k < len(splits) {
            tins = c.prog[splits[k]];
            if nd.greedy {
                tins.b = epos;
            } else {
                tins.a = epos;
            }
            k += 1;
        }
        return;
    }
    if kind == _K.BACKREF {
        _emit(c, _OP.BACKREF, nd.lo, 0);
        return;
    }
    if kind == _K.LOOK {
        li: int = _emit(c, _OP.LOOK, 0, nd.lo);
        ji: int = _emit(c, _OP.JMP, 0, 0);
        lins: _Ins = c.prog[li];
        lins.a = len(c.prog);
        _compile_node(nd.kids[0], c);
        _emit(c, _OP.MATCH, 0, 0);
        jins: _Ins = c.prog[ji];
        jins.a = len(c.prog);
        return;
    }
    if kind == _K.FLAGS {
        _emit(c, _OP.FPUSH, nd.lo, 0);
        _compile_node(nd.kids[0], c);
        _emit(c, _OP.FPOP, 0, 0);
        return;
    }
}


obj _Re {
    has prog: list[_Ins] = [],
        classes: list[_Cls] = [],
        ngroups: int = 0,
        names: dict[str, int] = {},
        nmarks: int = 0,
        flags: int = 0,
        pattern: str = "";
}


obj _St {
    has cps: list[int] = [],
        n: int = 0,
        slots: list[int] = [],
        marks: list[int] = [],
        fstack: list[int] = [],
        flags: int = 0;
}


def _bt3(stk: list[int], tag: int, x: int, y: int) {
    stk.append(tag);
    stk.append(x);
    stk.append(y);
}


def _run(re: _Re, st: _St, pc0: int, pos0: int) -> int {
    pc: int = pc0;
    pos: int = pos0;
    cps: list[int] = st.cps;
    n: int = st.n;
    prog: list[_Ins] = re.prog;
    stk: list[int] = [];
    while True {
        ins: _Ins = prog[pc];
        op: _OP = ins.op;
        if op == _OP.CHAR {
            if pos < n {
                c0: int = cps[pos];
                if c0 == ins.a or ((st.flags & 2) != 0 and swapcase(c0) == ins.a) {
                    pos += 1;
                    pc += 1;
                    continue;
                }
            }
        } elif op == _OP.ANY {
            if pos < n and ((st.flags & 16) != 0 or cps[pos] != 10) {
                pos += 1;
                pc += 1;
                continue;
            }
        } elif op == _OP.CLASS {
            if pos < n {
                cl: _Cls = re.classes[ins.a];
                c1: int = cps[pos];
                hit: bool = _in_pairs(cl.pairs, c1);
                if not hit and (st.flags & 2) != 0 {
                    hit = _in_pairs(cl.pairs, swapcase(c1));
                }
                if hit != cl.neg {
                    pos += 1;
                    pc += 1;
                    continue;
                }
            }
        } elif op == _OP.SPLIT {
            _bt3(stk, _BT_SPLIT, ins.b, pos);
            pc = ins.a;
            continue;
        } elif op == _OP.JMP {
            pc = ins.a;
            continue;
        } elif op == _OP.MARK {
            _bt3(stk, _BT_MARK, ins.a, st.marks[ins.a]);
            st.marks[ins.a] = pos;
            pc += 1;
            continue;
        } elif op == _OP.JMPNZ {
            if st.marks[ins.a] != pos {
                pc = ins.b;
            } else {
                pc += 1;
            }
            continue;
        } elif op == _OP.SAVE {
            _bt3(stk, _BT_SAVE, ins.a, st.slots[ins.a]);
            st.slots[ins.a] = pos;
            pc += 1;
            continue;
        } elif op == _OP.MATCH {
            return pos;
        } elif op == _OP.BOS {
            if pos == 0 {
                pc += 1;
                continue;
            }
        } elif op == _OP.BEGLINE {
            if pos == 0 or cps[pos - 1] == 10 {
                pc += 1;
                continue;
            }
        } elif op == _OP.END {
            if pos == n or (pos == n - 1 and cps[pos] == 10) {
                pc += 1;
                continue;
            }
        } elif op == _OP.ENDLINE {
            if pos == n or (pos < n and cps[pos] == 10) {
                pc += 1;
                continue;
            }
        } elif op == _OP.EOS {
            if pos == n {
                pc += 1;
                continue;
            }
        } elif op == _OP.WB {
            lft: bool = pos > 0 and is_word(cps[pos - 1]);
            rgt: bool = pos < n and is_word(cps[pos]);
            if (lft != rgt) == (ins.a == 0) {
                pc += 1;
                continue;
            }
        } elif op == _OP.BACKREF {
            g: int = ins.a * 2;
            lo: int = st.slots[g];
            hi: int = st.slots[g + 1];
            if lo >= 0 and hi >= lo {
                ln: int = hi - lo;
                if pos + ln <= n {
                    k2: int = 0;
                    ok: bool = True;
                    while k2 < ln {
                        ca: int = cps[lo + k2];
                        cb: int = cps[pos + k2];
                        if ca != cb and ((st.flags & 2) == 0 or swapcase(ca) != cb) {
                            ok = False;
                            break;
                        }
                        k2 += 1;
                    }
                    if ok {
                        pos += ln;
                        pc += 1;
                        continue;
                    }
                }
            }
        } elif op == _OP.FPUSH {
            _bt3(stk, _BT_FPUSH, st.flags, 0);
            st.fstack.append(st.flags);
            st.flags = ins.a;
            pc += 1;
            continue;
        } elif op == _OP.FPOP {
            if len(st.fstack) > 0 {
                _bt3(stk, _BT_FPOP, st.fstack[len(st.fstack) - 1], st.flags);
                st.flags = st.fstack.pop();
            }
            pc += 1;
            continue;
        } elif op == _OP.LOOK {
            if ins.b == 0 {
                r4: int = _run(re, st, ins.a, pos);
                if r4 >= 0 {
                    pc += 1;
                    continue;
                }
            } else {
                saved: list[int] = st.slots[:];
                r5: int = _run(re, st, ins.a, pos);
                st.slots = saved;
                if r5 < 0 {
                    pc += 1;
                    continue;
                }
            }
        }
        retry: bool = False;
        while len(stk) > 0 {
            y: int = stk.pop();
            x: int = stk.pop();
            tag: int = stk.pop();
            if tag == _BT_SPLIT {
                pc = x;
                pos = y;
                retry = True;
                break;
            }
            if tag == _BT_SAVE {
                st.slots[x] = y;
                continue;
            }
            if tag == _BT_MARK {
                st.marks[x] = y;
                continue;
            }
            if tag == _BT_FPUSH {
                st.fstack.pop();
                st.flags = x;
                continue;
            }
            if tag == _BT_FPOP {
                if x >= 0 {
                    st.fstack.append(x);
                }
                st.flags = y;
                continue;
            }
        }
        if not retry {
            return -1;
        }
    }
}


def _new_st(cps: list[int], n: int, re: _Re) -> _St {
    st: _St = _St();
    st.cps = cps;
    st.n = n;
    st.flags = re.flags;
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
    st.fstack = [];
    return st;
}


def _reset_slots(st: _St) {
    i: int = 0;
    while i < len(st.slots) {
        st.slots[i] = -1;
        i += 1;
    }
    st.fstack = [];
}


obj:pub Match {
    has _re: _Re,
        string: str = "",
        _bv: bytes = b"",
        pos: int = 0,
        endpos: int = 0,
        _slots: list[int] = [];

    def init(
        _re: _Re, string: str, bv: bytes, pos: int, endpos: int, slots: list[int]
    ) {
        self._re = _re;
        self.string = string;
        self._bv = bv;
        self.pos = pos;
        self.endpos = endpos;
        self._slots = slots;
    }

    def _gtext(num: int) -> str {
        lo: int = self._slots[num * 2];
        hi: int = self._slots[num * 2 + 1];
        if lo < 0 or hi < lo {
            return "";
        }
        return cpslice_str(self._bv, lo, hi);
    }

    def _gnum(i: (int | str)) -> int {
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

    def group(i: (int | str) = 0) -> any {
        g: int = self._gnum(i);
        lo: int = self._slots[g * 2];
        hi: int = self._slots[g * 2 + 1];
        if lo < 0 or hi < lo {
            return None;
        }
        return self._gtext(g);
    }

    def groups(`default: any = None) -> list[any] {
        out: list[any] = [];
        g: int = 1;
        while g <= self._re.ngroups {
            lo: int = self._slots[g * 2];
            hi: int = self._slots[g * 2 + 1];
            if lo < 0 or hi < lo {
                out.append(`default);
            } else {
                out.append(self._gtext(g));
            }
            g += 1;
        }
        return out;
    }

    def groupdict(`default: any = None) -> dict[str, any] {
        out: dict[str, any] = {};
        for nm in self._re.names {
            g: int = self._re.names[nm];
            lo: int = self._slots[g * 2];
            hi: int = self._slots[g * 2 + 1];
            if lo < 0 or hi < lo {
                out[nm] = `default;
            } else {
                out[nm] = self._gtext(g);
            }
        }
        return out;
    }

    def start(i: (int | str) = 0) -> int {
        g: int = self._gnum(i);
        return self._slots[g * 2];
    }

    def end(i: (int | str) = 0) -> int {
        g: int = self._gnum(i);
        return self._slots[g * 2 + 1];
    }

    def span(i: (int | str) = 0) -> tuple[(int, int)] {
        g: int = self._gnum(i);
        return (self._slots[g * 2], self._slots[g * 2 + 1]);
    }

    def expand(template: str) -> str {
        return _expand_repl(template, self, self._re);
    }
}


def _push_str(out: list[int], s: str) {
    k: int = 0;
    while k < len(s) {
        out.append(ord(s[k]));
        k += 1;
    }
}


def _push_range(out: list[int], pb: bytes, a: int, b: int) {
    k: int = a;
    while k < b {
        out.append(pb[k]);
        k += 1;
    }
}


def _posix_translate(pat: str, flags: int) -> (str | None) {
    if flags & (TEMPLATE | LOCALE | MULTILINE | DOTALL | VERBOSE) {
        return None;
    }
    pb: bytes = pat.encode();
    n: int = len(pb);
    out: list[int] = [];
    i: int = 0;
    inclass: bool = False;
    class_first: bool = False;
    prev_quant: bool = False;
    while i < n {
        c: int = pb[i];
        if inclass {
            if c == 92 or c == 91 {
                return None;
            }
            if c == 93 and not class_first {
                inclass = False;
            }
            out.append(c);
            class_first = False;
            i += 1;
            continue;
        }
        if c == 92 {
            if i + 1 >= n {
                return None;
            }
            e: int = pb[i + 1];
            if e == 100 {
                _push_str(out, "[0-9]");
            } elif e == 68 {
                _push_str(out, "[^0-9]");
            } elif e == 119 or e == 87 or e == 115 or e == 83 {
                _push_range(out, pb, i, i + 2);
            } elif e == 110 {
                out.append(10);
            } elif e == 116 {
                out.append(9);
            } elif e == 114 {
                out.append(13);
            } elif e == 102 {
                out.append(12);
            } elif e == 118 {
                out.append(11);
            } elif e == 97 {
                out.append(7);
            } elif (e >= 33 and e <= 47)
                or (e >= 58 and e <= 64)
                or (e >= 91 and e <= 96)
                or (e >= 123 and e <= 126) {
                out.append(91);
                out.append(e);
                out.append(93);
            } else {
                return None;
            }
            i += 2;
            prev_quant = False;
            continue;
        }
        if c == 124 or c == 94 or c == 36 {
            return None;
        }
        if c == 46 {
            _push_str(out, "[^\n]");
            i += 1;
            prev_quant = False;
            continue;
        }
        if c == 40 {
            if i + 1 < n and pb[i + 1] == 63 {
                return None;
            }
            out.append(40);
            i += 1;
            prev_quant = False;
            continue;
        }
        if c == 123 {
            j: int = i + 1;
            if j < n and pb[j] == 44 {
                k: int = j + 1;
                ok: bool = True;
                while k < n and pb[k] != 125 {
                    if not is_digit(pb[k]) {
                        ok = False;
                        break;
                    }
                    k += 1;
                }
                if not ok or k >= n or k == j + 1 {
                    return None;
                }
                _push_str(out, "{0");
                _push_range(out, pb, j, k + 1);
                i = k + 1;
                prev_quant = True;
                continue;
            }
            k2: int = j;
            ndig: int = 0;
            ncomma: int = 0;
            ok2: bool = True;
            while k2 < n and pb[k2] != 125 {
                ch2: int = pb[k2];
                if is_digit(ch2) {
                    ndig += 1;
                } elif ch2 == 44 {
                    ncomma += 1;
                    if ncomma > 1 {
                        ok2 = False;
                        break;
                    }
                } else {
                    ok2 = False;
                    break;
                }
                k2 += 1;
            }
            if not ok2 or k2 >= n or ndig == 0 {
                return None;
            }
            _push_range(out, pb, i, k2 + 1);
            i = k2 + 1;
            prev_quant = True;
            continue;
        }
        if c == 42 or c == 43 or c == 63 {
            if prev_quant {
                return None;
            }
            out.append(c);
            i += 1;
            prev_quant = True;
            continue;
        }
        if c == 91 {
            inclass = True;
            class_first = True;
            out.append(91);
            i += 1;
            if i < n and pb[i] == 94 {
                out.append(94);
                i += 1;
            }
            prev_quant = False;
            continue;
        }
        out.append(c);
        i += 1;
        prev_quant = False;
    }
    if inclass {
        return None;
    }
    return bytes(out).decode();
}


obj:pub Pattern {
    has _re: _Re,
        pattern: str = "",
        flags: int = 0,
        groups: int = 0,
        groupindex: dict[str, int] = {},
        _preg: bytes = b"",
        _pgen: int = -1,
        _posix: bool = False;

    def init(pattern: str, flags: int = 0) {
        self.pattern = pattern;
        self.flags = flags;
        self._re = _compile_re(pattern, flags);
        self.groups = self._re.ngroups;
        self.groupindex = self._re.names;
        if _PMW > 0 {
            ep: (str | None) = _posix_translate(pattern, flags);
            if ep is not None {
                preg: bytes = posix_compile(ep, (flags & IGNORECASE) != 0);
                if len(preg) > 0 {
                    _PSX.pregs.append(preg);
                    self._preg = preg;
                    self._pgen = _PSX.gen;
                    self._posix = True;
                }
            }
        }
    }

    def _use_posix(bv: bytes) -> bool {
        return self._posix and self._pgen == _PSX.gen and is_ascii(bv);
    }

    def _pm_slots(pm: bytes, bv: bytes, base: int) -> list[int] {
        slots: list[int] = [];
        g: int = 0;
        while g <= self.groups {
            so: int = pm_off(pm, _PMW, g * 2);
            eo: int = pm_off(pm, _PMW, g * 2 + 1);
            if so < 0 or eo < so {
                slots.append(-1);
                slots.append(-1);
            } else {
                slots.append(cp_len(bv, base + so));
                slots.append(cp_len(bv, base + eo));
            }
            g += 1;
        }
        return slots;
    }

    def _scan_from(st: _St, start: int) -> int {
        p: int = start;
        while p <= st.n {
            _reset_slots(st);
            st.flags = self._re.flags;
            r: int = _run(self._re, st, 0, p);
            if r >= 0 {
                st.slots[0] = p;
                st.slots[1] = r;
                return r;
            }
            p += 1;
        }
        return -1;
    }

    def _search_from(
        string: str, bv: bytes, start: int, endpos: int
    ) -> (Match | None) {
        if self._use_posix(bv) {
            bp: int = cp_off(bv, start);
            pm: bytes = posix_exec(
                self._preg, bv[bp:cp_off(bv, endpos)].decode(), self.groups + 1, _PMW
            );
            if len(pm) == 0 {
                return None;
            }
            return Match(
                self._re, string, bv, start, endpos, self._pm_slots(pm, bv, bp)
            );
        }
        st: _St = _new_st(utf8_cps(bv), endpos, self._re);
        r: int = self._scan_from(st, start);
        if r < 0 {
            return None;
        }
        return Match(self._re, string, bv, start, endpos, st.slots);
    }

    def search(string: str, pos: int = 0, endpos: int = _MAXPOS) -> (Match | None) {
        bv: bytes = string.encode();
        b: tuple[(int, int)] = _bounds(cp_len(bv, len(bv)), pos, endpos);
        pos = b[0];
        endpos = b[1];
        if pos > endpos {
            return None;
        }
        return self._search_from(string, bv, pos, endpos);
    }

    def `match(string: str, pos: int = 0, endpos: int = _MAXPOS) -> (Match | None) {
        bv: bytes = string.encode();
        b: tuple[(int, int)] = _bounds(cp_len(bv, len(bv)), pos, endpos);
        pos = b[0];
        endpos = b[1];
        if pos > endpos {
            return None;
        }
        if self._use_posix(bv) {
            bp: int = cp_off(bv, pos);
            pm: bytes = posix_exec(
                self._preg, bv[bp:cp_off(bv, endpos)].decode(), self.groups + 1, _PMW
            );
            if len(pm) == 0 or pm_off(pm, _PMW, 0) != 0 {
                return None;
            }
            return Match(self._re, string, bv, pos, endpos, self._pm_slots(pm, bv, bp));
        }
        st: _St = _new_st(utf8_cps(bv), endpos, self._re);
        r: int = _run(self._re, st, 0, pos);
        if r < 0 {
            return None;
        }
        st.slots[0] = pos;
        st.slots[1] = r;
        return Match(self._re, string, bv, pos, endpos, st.slots);
    }

    def fullmatch(string: str, pos: int = 0, endpos: int = _MAXPOS) -> (Match | None) {
        m: (Match | None) = self.match(string, pos, endpos);
        if m is None {
            return None;
        }
        m2: Match = m;
        if m2._slots[1] != m2.endpos {
            return None;
        }
        return m2;
    }

    def finditer(string: str, pos: int = 0, endpos: int = _MAXPOS) -> list[Match] {
        bv: bytes = string.encode();
        b: tuple[(int, int)] = _bounds(cp_len(bv, len(bv)), pos, endpos);
        pos = b[0];
        endpos = b[1];
        out: list[Match] = [];
        if self._use_posix(bv) {
            p: int = cp_off(bv, pos);
            be: int = cp_off(bv, endpos);
            while p <= be {
                pm: bytes = posix_exec(
                    self._preg, bv[p:be].decode(), self.groups + 1, _PMW
                );
                if len(pm) == 0 {
                    break;
                }
                m2: Match = Match(
                    self._re, string, bv, pos, endpos, self._pm_slots(pm, bv, p)
                );
                out.append(m2);
                nxt: int = p + pm_off(pm, _PMW, 1);
                if nxt > p {
                    p = nxt;
                } else {
                    p = nxt + 1;
                }
            }
            return out;
        }
        st: _St = _new_st(utf8_cps(bv), endpos, self._re);
        p = pos;
        while p <= endpos {
            r: int = self._scan_from(st, p);
            if r < 0 {
                break;
            }
            m2 = Match(self._re, string, bv, pos, endpos, st.slots[:]);
            out.append(m2);
            if r > p {
                p = r;
            } else {
                p = r + 1;
            }
        }
        return out;
    }

    def findall(string: str, pos: int = 0, endpos: int = _MAXPOS) -> list[str] {
        if self._re.ngroups > 1 {
            raise ValueError(
                "findall: patterns with more than one group are not supported on native"
            );
        }
        bv: bytes = string.encode();
        b: tuple[(int, int)] = _bounds(cp_len(bv, len(bv)), pos, endpos);
        pos = b[0];
        endpos = b[1];
        out: list[str] = [];
        if self._use_posix(bv) {
            p: int = cp_off(bv, pos);
            be: int = cp_off(bv, endpos);
            while p <= be {
                pm: bytes = posix_exec(
                    self._preg, bv[p:be].decode(), self.groups + 1, _PMW
                );
                if len(pm) == 0 {
                    break;
                }
                if self._re.ngroups == 0 {
                    out.append(
                        bv[p + pm_off(pm, _PMW, 0):p + pm_off(pm, _PMW, 1)].decode()
                    );
                } else {
                    lo: int = pm_off(pm, _PMW, 2);
                    hi: int = pm_off(pm, _PMW, 3);
                    if lo < 0 or hi < lo {
                        out.append("");
                    } else {
                        out.append(bv[p + lo:p + hi].decode());
                    }
                }
                nxt: int = p + pm_off(pm, _PMW, 1);
                if nxt > p {
                    p = nxt;
                } else {
                    p = nxt + 1;
                }
            }
            return out;
        }
        st: _St = _new_st(utf8_cps(bv), endpos, self._re);
        p = pos;
        while p <= endpos {
            r: int = self._scan_from(st, p);
            if r < 0 {
                break;
            }
            if self._re.ngroups == 0 {
                out.append(cpslice_str(bv, st.slots[0], r));
            } else {
                lo = st.slots[2];
                hi = st.slots[3];
                if lo < 0 or hi < lo {
                    out.append("");
                } else {
                    out.append(cpslice_str(bv, lo, hi));
                }
            }
            if r > p {
                p = r;
            } else {
                p = r + 1;
            }
        }
        return out;
    }

    def split(string: str, maxsplit: int = 0) -> list[any] {
        bv: bytes = string.encode();
        n: int = cp_len(bv, len(bv));
        out: list[any] = [];
        last: int = 0;
        count: int = 0;
        if self._use_posix(bv) {
            p: int = 0;
            nb: int = len(bv);
            while p <= nb {
                pm: bytes = posix_exec(
                    self._preg, bv[p:nb].decode(), self.groups + 1, _PMW
                );
                if len(pm) == 0 {
                    break;
                }
                if maxsplit > 0 and count >= maxsplit {
                    break;
                }
                m0: int = p + pm_off(pm, _PMW, 0);
                m1: int = p + pm_off(pm, _PMW, 1);
                out.append(bv[last:m0].decode());
                g: int = 1;
                while g <= self._re.ngroups {
                    lo: int = pm_off(pm, _PMW, g * 2);
                    hi: int = pm_off(pm, _PMW, g * 2 + 1);
                    if lo < 0 or hi < lo {
                        out.append(None);
                    } else {
                        out.append(bv[p + lo:p + hi].decode());
                    }
                    g += 1;
                }
                last = m1;
                count += 1;
                if m1 > p {
                    p = m1;
                } else {
                    p = m1 + 1;
                }
            }
            out.append(bv[last:nb].decode());
            return out;
        }
        st: _St = _new_st(utf8_cps(bv), n, self._re);
        p = 0;
        while p <= n {
            r: int = self._scan_from(st, p);
            if r < 0 {
                break;
            }
            if maxsplit > 0 and count >= maxsplit {
                break;
            }
            out.append(cpslice_str(bv, last, st.slots[0]));
            g = 1;
            while g <= self._re.ngroups {
                lo = st.slots[g * 2];
                hi = st.slots[g * 2 + 1];
                if lo < 0 or hi < lo {
                    out.append(None);
                } else {
                    out.append(cpslice_str(bv, lo, hi));
                }
                g += 1;
            }
            last = r;
            count += 1;
            if r > p {
                p = r;
            } else {
                p = r + 1;
            }
        }
        out.append(cpslice_str(bv, last, n));
        return out;
    }

    def _subn(repl: str, string: str, count: int) -> tuple[(str, int)] {
        bv: bytes = string.encode();
        n: int = cp_len(bv, len(bv));
        out: str = "";
        last: int = 0;
        nsub: int = 0;
        if self._use_posix(bv) {
            p: int = 0;
            nb: int = len(bv);
            while p <= nb {
                if count != 0 and nsub >= count {
                    break;
                }
                pm: bytes = posix_exec(
                    self._preg, bv[p:nb].decode(), self.groups + 1, _PMW
                );
                if len(pm) == 0 {
                    break;
                }
                m2: Match = Match(
                    self._re, string, bv, 0, n, self._pm_slots(pm, bv, p)
                );
                m0: int = p + pm_off(pm, _PMW, 0);
                m1: int = p + pm_off(pm, _PMW, 1);
                out += bv[last:m0].decode();
                out += _expand_repl(repl, m2, self._re);
                nsub += 1;
                last = m1;
                if m1 > p {
                    p = m1;
                } else {
                    p = m1 + 1;
                }
            }
            out += bv[last:nb].decode();
            return (out, nsub);
        }
        st: _St = _new_st(utf8_cps(bv), n, self._re);
        p = 0;
        while p <= n {
            if count != 0 and nsub >= count {
                break;
            }
            r: int = self._scan_from(st, p);
            if r < 0 {
                break;
            }
            m2: Match = Match(self._re, string, bv, p, n, st.slots[:]);
            out += cpslice_str(bv, last, st.slots[0]);
            out += _expand_repl(repl, m2, self._re);
            nsub += 1;
            last = r;
            if r > p {
                p = r;
            } else {
                p = r + 1;
            }
        }
        out += cpslice_str(bv, last, n);
        return (out, nsub);
    }

    def sub(repl: str, string: str, count: int = 0) -> str {
        r: tuple[(str, int)] = self._subn(repl, string, count);
        return r[0];
    }

    def subn(repl: str, string: str, count: int = 0) -> tuple[(str, int)] {
        return self._subn(repl, string, count);
    }
}


def _compile_re(pattern: str, flags: int) -> _Re {
    p: _P = _P();
    p.cps = utf8_cps(pattern.encode());
    p.n = len(p.cps);
    p.flags = flags;
    tree: _Node = p._parse();
    c: _C = _C();
    _compile_node(tree, c);
    _emit(c, _OP.MATCH, 0, 0);
    re: _Re = _Re();
    re.prog = c.prog;
    re.classes = c.classes;
    re.ngroups = p.ngroups;
    re.names = p.names;
    re.nmarks = c.nmarks;
    re.flags = p.flags;
    re.pattern = pattern;
    return re;
}


def _expand_repl(template: str, m: Match, re: _Re) -> str {
    tps: list[int] = utf8_cps(template.encode());
    out: str = "";
    i: int = 0;
    n: int = len(tps);
    while i < n {
        c: int = tps[i];
        if c != 92 {
            out += chr(c);
            i += 1;
            continue;
        }
        bp: int = i;
        i += 1;
        if i >= n {
            raise ValueError("bad escape (end of pattern) at position " + str(bp));
        }
        e: int = tps[i];
        i += 1;
        if e == 103 {
            if i >= n or tps[i] != 60 {
                raise ValueError("missing < at position " + str(i));
            }
            i += 1;
            j: int = i;
            while j < n and tps[j] != 62 {
                j += 1;
            }
            if j >= n {
                raise ValueError("missing unterminated name at position " + str(i));
            }
            nm: str = cps_str(tps, i, j);
            i = j + 1;
            num: int = -1;
            if len(nm) > 0 {
                alldig: bool = True;
                k: int = 0;
                while k < len(nm) {
                    if not is_digit(ord(nm[k])) {
                        alldig = False;
                    }
                    k += 1;
                }
                if alldig {
                    num = 0;
                    k = 0;
                    while k < len(nm) {
                        num = num * 10 + (ord(nm[k]) - 48);
                        k += 1;
                    }
                }
            }
            if num < 0 {
                num = _name_index(re.names, nm);
                if num < 0 {
                    raise ValueError("unknown group name '" + nm + "'");
                }
            }
            if num > re.ngroups {
                raise ValueError(
                    "invalid group reference " + str(num) + " at position " + str(j)
                );
            }
            out += m._gtext(num);
            continue;
        }
        if e >= 49 and e <= 57 {
            num = e - 48;
            if i < n and is_digit(tps[i]) {
                num = num * 10 + (tps[i] - 48);
                i += 1;
            }
            if num > re.ngroups {
                raise ValueError(
                    "invalid group reference "
                        + str(num)
                        + " at position "
                        + str(bp + 1)
                );
            }
            out += m._gtext(num);
            continue;
        }
        if e == 48 or e == 120 {
            r: tuple[(int, int)] = _num_esc(tps, i, e, bp);
            i = r[1];
            out += chr(r[0]);
            continue;
        }
        if e == 110 {
            out += "\n";
            continue;
        }
        if e == 114 {
            out += "\r";
            continue;
        }
        if e == 116 {
            out += "\t";
            continue;
        }
        if e == 102 {
            out += "\x0c";
            continue;
        }
        if e == 118 {
            out += "\x0b";
            continue;
        }
        if e == 97 {
            out += "\x07";
            continue;
        }
        if is_alpha(e) {
            raise ValueError("bad escape \\" + chr(e) + " at position " + str(bp));
        }
        out += chr(e);
    }
    return out;
}


def:pub compile(pattern: str, flags: int = 0) -> Pattern {
    return Pattern(pattern, flags);
}


def:pub search(pattern: str, string: str, flags: int = 0) -> (Match | None) {
    p: Pattern = Pattern(pattern, flags);
    return p.search(string);
}


def:pub `match(pattern: str, string: str, flags: int = 0) -> (Match | None) {
    p: Pattern = Pattern(pattern, flags);
    return p.`match(string);
}


def:pub fullmatch(pattern: str, string: str, flags: int = 0) -> (Match | None) {
    p: Pattern = Pattern(pattern, flags);
    return p.fullmatch(string);
}


def:pub findall(pattern: str, string: str, flags: int = 0) -> list[str] {
    p: Pattern = Pattern(pattern, flags);
    return p.findall(string);
}


def:pub finditer(pattern: str, string: str, flags: int = 0) -> list[Match] {
    p: Pattern = Pattern(pattern, flags);
    return p.finditer(string);
}


def:pub split(
    pattern: str, string: str, maxsplit: int = 0, flags: int = 0
) -> list[any] {
    p: Pattern = Pattern(pattern, flags);
    return p.split(string, maxsplit);
}


def:pub sub(
    pattern: str, repl: str, string: str, count: int = 0, flags: int = 0
) -> str {
    p: Pattern = Pattern(pattern, flags);
    return p.sub(repl, string, count);
}


def:pub subn(
    pattern: str, repl: str, string: str, count: int = 0, flags: int = 0
) -> tuple[(str, int)] {
    p: Pattern = Pattern(pattern, flags);
    return p.subn(repl, string, count);
}


def:pub escape(pattern: str) -> str {
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


def:pub purge {
    while len(_PSX.pregs) > 0 {
        posix_free(_PSX.pregs.pop());
    }
    _PSX.gen += 1;
}
