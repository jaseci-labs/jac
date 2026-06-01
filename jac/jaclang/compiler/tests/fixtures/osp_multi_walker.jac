"""Cross-backend OSP equivalence fixture: independent walkers don't share state.

Two `Acc` walkers spawn against their own `Item`s; each accumulates only its own
visits (`a` spawns twice -> 10, `b` once -> 100). This pins per-walker state
isolation: the kernel's `WalkScope` is per-spawn, so interleaved spawns never
cross-contaminate.

Entry-only (no visit/edges), so na participates today via the inline spawn
path. cl OSP is still unwired (spawn lowers to an unbound `__jacSpawn`), so it
is skipped automatically until Phase 3.
"""

node Item { has val: int; }

walker Acc {
    has total: int = 0;
    can grab with Item entry {
        self.total = self.total + here.val;
    }
}

def multi_walker_py() -> dict[str, any] {
    a = Acc();
    b = Acc();
    a spawn Item(val=5);
    b spawn Item(val=100);
    a spawn Item(val=5);
    return {"a": a.total, "b": b.total};
}

na {
    def multi_walker_na() -> dict[str, any] {
        a = Acc();
        b = Acc();
        a spawn Item(val=5);
        b spawn Item(val=100);
        a spawn Item(val=5);
        return {"a": a.total, "b": b.total};
    }
}
