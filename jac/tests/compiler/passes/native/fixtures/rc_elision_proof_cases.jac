"""Fixtures for RcElisionProofPass. Each function has one `bN = a` candidate; the
proof must mark exactly the sound ones. Compiled with `type_check=False`, so the
marks come purely from the native proof, never the ownership checker."""

obj Box { has v: int = 0; }

obj Holder { has inner: Box; }

def take(x: Box) -> int {
    return 1;
}

# 1. Safe straight-line last-use move: `a` is a local whose only use is the move,
#    dead after -> b1 MUST be marked.
def f_safe() -> int {
    a: own Box = Box(v=1);
    b1 = a;
    return take(b1);
}

# 2. Source is a param (storage != LOCAL) -> b2 MUST NOT be marked. This is the
#    own-param UAF channel, now unrepresentable.
def f_param(a: own Box) -> int {
    b2 = a;
    return take(b2);
}

# 3. Source is passed as a call-arg (a non-alias use) -> disqualified -> b3 NOT.
def f_callarg() -> int {
    a: own Box = Box(v=1);
    take(a);
    b3 = a;
    return take(b3);
}

# 4. Source stored into a field (escapes) -> disqualified -> b4 NOT.
def f_fieldstore() -> int {
    a: own Box = Box(v=1);
    h = Holder(inner=Box());
    h.inner = a;
    b4 = a;
    return take(b4);
}

# 5. Source captured by a closure -> disqualified -> b5 NOT.
def f_closure() -> int {
    a: own Box = Box(v=1);
    g = lambda : a;
    b5 = a;
    return take(b5);
}

# 6. Source captured by a concurrent payload -> disqualified -> b6 NOT.
def f_concurrent() -> int {
    a: own Box = Box(v=1);
    flow take(a);
    b6 = a;
    return take(b6);
}

# 7. Source borrowed (`&a`, a non-alias use) -> disqualified -> b7 NOT.
def f_borrow() -> int {
    a: own Box = Box(v=1);
    r: &Box = &a;
    b7 = a;
    return take(b7);
}

# 8. Loop hazard: `a` defined OUTSIDE the loop, moved inside with no redefinition.
#    A later use is reached via the back-edge, so `a` is live-out -> b8 NOT.
def f_loop_hazard(n: int) -> int {
    a: own Box = Box(v=0);
    total = 0;
    i = 0;
    while i < n {
        b8 = a;
        total = total + take(b8);
        i = i + 1;
    }
    return total;
}

# 9. Loop safe: `a` is redefined each iteration before the move, so it is dead-out
#    at the move site (the redef kills liveness on the back-edge) -> b9 marked.
def f_loop_safe(n: int) -> int {
    total = 0;
    i = 0;
    while i < n {
        a: own Box = Box(v=i);
        b9 = a;
        total = total + take(b9);
        i = i + 1;
    }
    return total;
}
