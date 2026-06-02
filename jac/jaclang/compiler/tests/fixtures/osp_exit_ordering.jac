"""Cross-backend OSP equivalence fixture: entry/exit interleaving over a tree.

Each location logs `+val` on entry and `-val` on exit. A parent's entry fires
before its children and its exit fires after them, so the log is
`[1, 2, 3, -3, -2, -1]` for `root(1) -> {a(2), b(3)}`.

Note the sibling ordering: `a`'s exit (`-2`) lands AFTER `b`'s entire visit
(`3`, `-3`), not between `a`'s entry and `b`'s. This is a property of the
kernel's single shared `next` queue -- enqueued siblings are drained within the
first sibling's recursion, so later siblings nest under earlier ones rather than
being independent subtrees. This fixture pins that exact behavior so every
backend reproduces it (and so a future "independent siblings" reconciliation is
a visible, intentional change here).

Backend status: exit abilities compile on na but do NOT fire (the inline spawn
stopgap is entry-only), and this also needs `visit`/edges; cl is unwired. So
py-only today -- add backend variants when exit firing + visit/edge lowering
land.
"""

node N { has val: int; }

walker Ex {
    has log: list = [];
    can enter with N entry {
        self.log.append(here.val);
        visit [-->];
    }
    can leave with N exit {
        self.log.append(0 - here.val);
    }
}

def exit_ordering_py() -> dict[str, any] {
    root_n = N(val=1); a = N(val=2); b = N(val=3);
    root_n ++> a; root_n ++> b;
    w = Ex();
    w spawn root_n;
    return {"order": w.log};
}
