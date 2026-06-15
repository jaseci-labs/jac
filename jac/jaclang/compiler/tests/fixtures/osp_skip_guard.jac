"""Cross-backend OSP equivalence fixture: `skip` + node-identity membership as
the user-managed visit-once guard, from issue #6636 (#2).

`skip` is Return-family: py lowers it to a bare `return`, cl to a
ReturnStatement. Native used to silently DROP it (only break/continue were
lowered), so the `if here in self.seen { skip; }` guard became dead code and
the second spawn re-counted the node — the documented cycle-guard pattern
silently computing the wrong answer.
"""

node Cell { has tag: int; }

walker Dedupe {
    has seen: list[Cell] = [], count: int = 0;
    can at_cell with Cell entry {
        if here in self.seen {
            skip;
        }
        self.seen.append(here);
        self.count += here.tag;
    }
}

def _dedupe_count() -> int {
    a = Cell(tag=1);
    d = Dedupe();
    d spawn a;
    d spawn a;
    return d.count;
}

# --- py reference (sv runtime) ---
def skip_guard_py() -> dict[str, any] {
    return {"count": _dedupe_count()};
}

# --- na (native LLVM) ---
na {
    def skip_guard_na() -> dict[str, any] {
        a = Cell(tag=1);
        d = Dedupe();
        d spawn a;
        d spawn a;
        return {"count": d.count};
    }
}

# --- cl (ECMAScript, in-process via the kernel) ---
cl {
    def skip_guard_cl() -> dict[str, any] {
        a = Cell(tag=1);
        d = Dedupe();
        d spawn a;
        d spawn a;
        return {"count": d.count};
    }
}
