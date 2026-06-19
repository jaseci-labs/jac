"""Cross-backend OSP equivalence fixture: `visit ... else` and post-`disengage`
unreachability (ability control flow).

Walker `Walk` traverses a chain `1 -> 2 -> 3`; `visit [-->] else` runs its else
body only where nothing was enqueued (the dead end `3`), so ends = 1. Walker
`Halt` disengages at `2` and then increments `tail` in the same block; the py
lowering emits `return` right after the disengage call, so the statement after
`disengage` must never run: tail = 0 and hseen = [1, 2].

Backend status: na and py agree -- native lowers `visit ... else` to a branch on
`osp_visit`'s "anything enqueued" result, and `disengage` terminates the ability
(mirroring py). cl lowers `visit`/`disengage` but drops the `else` body and does
not return after `disengage` (tracked upstream), so cl stays unrequired here;
flip to `require=["na", "cl"]` when cl gains both.
"""

node P { has val: int; }

walker Walk {
    has seen: list = [], ends: int = 0;
    can step with P entry {
        self.seen.append(here.val);
        visit [-->] else {
            self.ends = self.ends + 1;
        }
    }
}

walker Halt {
    has seen: list = [], tail: int = 0;
    can step with P entry {
        self.seen.append(here.val);
        if here.val == 2 {
            disengage;
            self.tail = self.tail + 1;
        }
        visit [-->];
    }
}

def visit_else_py() -> dict[str, any] {
    n1 = P(val=1); n2 = P(val=2); n3 = P(val=3);
    n1 ++> n2; n2 ++> n3;
    w = Walk();
    w spawn n1;
    h = Halt();
    h spawn n1;
    return {"seen": w.seen, "ends": w.ends, "hseen": h.seen, "tail": h.tail};
}

na {
    def visit_else_na() -> dict[str, any] {
        n1 = P(val=1); n2 = P(val=2); n3 = P(val=3);
        n1 ++> n2; n2 ++> n3;
        w = Walk();
        w spawn n1;
        h = Halt();
        h spawn n1;
        return {"seen": w.seen, "ends": w.ends, "hseen": h.seen, "tail": h.tail};
    }
}

cl {
    def visit_else_cl() -> dict[str, any] {
        n1 = P(val=1); n2 = P(val=2); n3 = P(val=3);
        n1 ++> n2; n2 ++> n3;
        w = Walk();
        w spawn n1;
        h = Halt();
        h spawn n1;
        return {"seen": w.seen, "ends": w.ends, "hseen": h.seen, "tail": h.tail};
    }
}
