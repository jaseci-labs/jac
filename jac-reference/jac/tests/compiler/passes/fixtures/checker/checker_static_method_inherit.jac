"""Test: scope narrowing isolation between impl bodies.

Regression test for a bug where guard-pattern narrowings (e.g.,
`if ctx is not None { return ctx; }` promoting ctx→NoneType to parent
scope) leaked from one impl body into subsequent impl bodies sharing the
same variable name.
"""

class MyContext {
    has mem: str,
        user_root: str;
}

def maybe_get() -> MyContext | None {
    return None;
}

class Base {
    static def get_ctx -> MyContext;
    static def commit -> None;
    static def reset_graph -> int;
}

# This impl has a guard pattern that narrows `ctx` to NoneType
# after the if-body returns.
impl Base.get_ctx -> MyContext {
    ctx = maybe_get();
    if ctx is not None {
        return ctx;
    }
    return MyContext(mem="default", user_root="root");
}

# Uses the same variable name `ctx` -- should NOT be polluted
# by the NoneType narrowing from get_ctx's body.
impl Base.commit -> None {
    ctx = Base.get_ctx();
    x: str = ctx.mem;
}

impl Base.reset_graph -> int {
    ctx = Base.get_ctx();
    m: str = ctx.mem;
    r: str = ctx.user_root;
    return 0;
}

# Also test inherited static method calls
class Child(Base) {}

with entry {
    Base.commit();
    n = Base.reset_graph();

    # Inherited static methods should also work
    c = Child.get_ctx();
    x: str = c.mem;
}
