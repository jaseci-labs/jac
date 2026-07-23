"""Transitive sibling-closure captures (#7626 C7: ts_decl_parser blocker).

The ts_decl_parser shape: a family of sibling nested fns share a parent
frame's locals (`toks`/`pos`), but only some of them touch those locals
directly -- the rest reach them *transitively* by calling capturing siblings
(`is_a` calls `kind_at`; `eat_a` calls `is_a` and `advance`). Native capture
handling used to stop at textual captures, so the sibling call sites died
with E5092 ("captured 'pos' not in the calling frame").
"""

def transitive_py -> dict {
    toks = ["a", "a", "b"];
    pos = 0;
    def kind_at -> str {
        return toks[pos] if pos < len(toks) else "";
    }
    def advance -> None {
        pos = pos + 1;
    }
    def is_a -> bool {
        return kind_at() == "a";
    }
    def eat_a -> bool {
        if is_a() {
            advance();
            return True;
        }
        return False;
    }
    r1 = eat_a();
    r2 = eat_a();
    r3 = eat_a();
    k = kind_at();
    return {"r1": r1, "r2": r2, "r3": r3, "k": k, "pos": pos};
}

def fwd_mutual_py -> dict {
    pos = 0;
    def parse_a(d: int) -> int {
        return parse_b(d) + 100;
    }
    def parse_b(d: int) -> int {
        if d <= 0 {
            pos = pos + 1;
            return pos;
        }
        return parse_a(d - 1);
    }
    r1 = parse_a(2);
    r2 = parse_b(0);
    return {"r1": r1, "r2": r2, "pos": pos};
}

cl def transitive_cl -> dict {
    return {};
}

cl def fwd_mutual_cl -> dict {
    return {};
}

na {
    def transitive_na -> dict[str, any] {
        toks = ["a", "a", "b"];
        pos = 0;
        def kind_at -> str {
            return toks[pos] if pos < len(toks) else "";
        }
        def advance -> None {
            pos = pos + 1;
        }
        def is_a -> bool {
            return kind_at() == "a";
        }
        def eat_a -> bool {
            if is_a() {
                advance();
                return True;
            }
            return False;
        }
        r1 = eat_a();
        r2 = eat_a();
        r3 = eat_a();
        k = kind_at();
        return {"r1": r1, "r2": r2, "r3": r3, "k": k, "pos": pos};
    }
    def fwd_mutual_na -> dict[str, any] {
        pos = 0;
        def parse_a(d: int) -> int {
            return parse_b(d) + 100;
        }
        def parse_b(d: int) -> int {
            if d <= 0 {
                pos = pos + 1;
                return pos;
            }
            return parse_a(d - 1);
        }
        r1 = parse_a(2);
        r2 = parse_b(0);
        return {"r1": r1, "r2": r2, "pos": pos};
    }
}
