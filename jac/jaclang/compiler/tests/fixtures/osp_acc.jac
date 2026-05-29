"""Cross-backend OSP equivalence fixture: a walker's typed entry ability
accumulates node state across spawns. Entry-only subset (no visit/edge-ref)
so the native backend participates; richer traversals are added as native OSP
support lands. Archetypes are declared once per codespace because each backend
compiles its own copy."""

# --- py reference (sv runtime) ---
node Item { has val: int; }

walker Acc {
    has total: int = 0;
    can grab with Item entry { self.total = self.total + here.val; }
}

def acc_py() -> dict {
    w = Acc();
    w spawn Item(val=10);
    w spawn Item(val=32);
    return {"total": w.total};
}

# --- na (native LLVM) ---
na {
    node Item { has val: int; }

    walker Acc {
        has total: int = 0;
        can grab with Item entry { self.total = self.total + here.val; }
    }

    def acc_na() -> dict[str, any] {
        w = Acc();
        w spawn Item(val=10);
        w spawn Item(val=32);
        return {"total": w.total};
    }
}
