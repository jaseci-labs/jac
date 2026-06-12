"""Cross-backend OSP equivalence fixture: a walker's typed entry ability
accumulates node state across spawns. Entry-only subset (no visit/edge-ref) so
the native backend participates; richer traversals are added as native OSP
support lands.

Archetypes are declared ONCE at module level: `obj`/`node`/`edge`/`walker`
declarations are shared across every codespace, so the same `Item`/`Acc` are
compiled by each backend that references them. Only the per-backend entry
functions live in their codespace block.
"""

# --- shared archetypes (one declaration, compiled by every backend) ---
node Item { has val: int; }

walker Acc {
    has total: int = 0;
    can grab with Item entry { self.total = self.total + here.val; }
}

# --- py reference (sv runtime) ---
def acc_py() -> dict[str, any] {
    w = Acc();
    w spawn Item(val=10);
    w spawn Item(val=32);
    return {"total": w.total};
}

# --- na (native LLVM) ---
na {
    def acc_na() -> dict[str, any] {
        w = Acc();
        w spawn Item(val=10);
        w spawn Item(val=32);
        return {"total": w.total};
    }
}

# --- cl (ECMAScript, in-process via the kernel) ---
cl {
    def acc_cl() -> dict[str, any] {
        w = Acc();
        w spawn Item(val=10);
        w spawn Item(val=32);
        return {"total": w.total};
    }
}
