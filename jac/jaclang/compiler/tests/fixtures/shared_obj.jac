"""Cross-backend shared-type fixture.

A module-level `obj` is declared ONCE and used by the py, cl, and na entry
functions without redeclaration. Guards the rule that module-level
`obj`/`node`/`edge`/`walker` declarations are shared across every codespace, and
that each backend's codegen materializes the shared types its own code
references (the type checker already resolves them into every codespace)."""

obj Pt { has x: int, y: int; }

def shared_py() -> dict {
    p = Pt(x=3, y=4);
    return {"sum": p.x + p.y};
}

cl def shared_cl() -> dict {
    p = Pt(x=3, y=4);
    return {"sum": p.x + p.y};
}

na {
    def shared_na() -> dict[str, any] {
        p = Pt(x=3, y=4);
        return {"sum": p.x + p.y};
    }
}
