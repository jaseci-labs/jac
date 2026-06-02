"""Cross-backend OSP equivalence fixture: `disengage` early-exit.

The walker steps along a chain `1 -> 2 -> 3 -> 4 -> 5`, recording each value,
and `disengage`s at `3`. `disengage` halts the walk after the in-flight ability
returns, so the partial visit-set `[1, 2, 3]` is captured and nodes 4/5 are
never entered.

Backend status: `disengage` is E5090 on na and unwired on cl (also needs
visit/edges), so py-only today.
"""

node N { has val: int; }

walker Stop {
    has seen: list = [];
    can step with N entry {
        self.seen.append(here.val);
        if here.val == 3 {
            disengage;
        } else {
            visit [-->];
        }
    }
}

def disengage_py() -> dict[str, any] {
    n1 = N(val=1); n2 = N(val=2); n3 = N(val=3); n4 = N(val=4); n5 = N(val=5);
    n1 ++> n2; n2 ++> n3; n3 ++> n4; n4 ++> n5;
    w = Stop();
    w spawn n1;
    return {"seen": w.seen};
}
