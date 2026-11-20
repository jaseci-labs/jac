"""Test reassignment inside narrowed branch updates post-join type."""

obj Ctx { has val: int; }

def make_ctx -> Ctx {
    return Ctx(val=42);
}

# Simple local: should work
def test_reassign_local(x: Ctx | None) -> Ctx {
    if x is None {
        x = make_ctx();
    }
    return x;
}

# Attribute read into local, then reassign local
obj Runtime {
    static has exec_ctx: Ctx | None = None;
}

def test_reassign_attr_local -> Ctx {
    ctx = Runtime.exec_ctx;
    if ctx is None {
        ctx = make_ctx();
        Runtime.exec_ctx = ctx;
    }
    return ctx;
}
