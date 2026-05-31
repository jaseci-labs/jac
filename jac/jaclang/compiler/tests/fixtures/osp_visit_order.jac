"""Cross-backend OSP equivalence fixture: `visit`-driven traversal order over
four graph shapes (linear chain, diamond, fan-out, cycle).

The portable kernel is DFS-recursive and does NOT auto-track visited locations
(visit-once is opt-in), so a diamond double-visits its shared sink and a cycle
would loop forever unless the walker guards itself. `chain`/`diamond`/`fanout`
use the unguarded `Tracer`; `cycle` uses `GuardedTracer`, which only recurses
into unseen nodes -- the canonical user-managed visit-once pattern.

Backend status: `visit` and edge connect/ref (`++>`, `[-->]`) are E5090 on na
and unwired on cl, so this runs py-only today. When visit/edge lowering lands,
add `na {}` / `cl {}` entry variants and flip `require=` in the test.
"""

node Pos { has val: int; }

walker Tracer {
    has seen: list = [];
    can step with Pos entry {
        self.seen.append(here.val);
        visit [-->];
    }
}

walker GuardedTracer {
    has seen: list = [];
    can step with Pos entry {
        if here.val not in self.seen {
            self.seen.append(here.val);
            visit [-->];
        }
    }
}

def _chain() -> list {
    n1 = Pos(val=1); n2 = Pos(val=2); n3 = Pos(val=3); n4 = Pos(val=4);
    n1 ++> n2; n2 ++> n3; n3 ++> n4;
    w = Tracer();
    w spawn n1;
    return w.seen;
}

def _diamond() -> list {
    # a -> b, a -> c, b -> d, c -> d : shared sink `d` is visited via both paths.
    a = Pos(val=1); b = Pos(val=2); c = Pos(val=3); d = Pos(val=4);
    a ++> b; a ++> c; b ++> d; c ++> d;
    w = Tracer();
    w spawn a;
    return w.seen;
}

def _fanout() -> list {
    root_n = Pos(val=1);
    c1 = Pos(val=2); c2 = Pos(val=3); c3 = Pos(val=4);
    root_n ++> c1; root_n ++> c2; root_n ++> c3;
    w = Tracer();
    w spawn root_n;
    return w.seen;
}

def _cycle() -> list {
    # 1 -> 2 -> 3 -> 1 : the guard stops the walk re-entering `1`.
    n1 = Pos(val=1); n2 = Pos(val=2); n3 = Pos(val=3);
    n1 ++> n2; n2 ++> n3; n3 ++> n1;
    w = GuardedTracer();
    w spawn n1;
    return w.seen;
}

def visit_order_py() -> dict[str, any] {
    return {
        "chain": _chain(),
        "diamond": _diamond(),
        "fanout": _fanout(),
        "cycle": _cycle()
    };
}
