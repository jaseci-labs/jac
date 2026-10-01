"""Fixtures for RcFactsPass move-lowerability proofs. Each function has one `bN = a` candidate; the
proof must mark exactly the sound ones. The marks come purely from the native
proof, never the ownership checker. The checker runs on every compile now, so
each hazard source is a plain RC-managed local (the checker only tracks `own`
bindings, and a real `own` UAF no longer compiles); the proof ignores the
declaration's ownership either way -- it reasons from uses and liveness."""

obj Box {
    has v: int = 0;
}

obj Holder {
    has inner: Box;
}

def take(x: Box) -> int {
    return 1;
}

def consume(x: str) -> int {
    return len(x);
}

# 1. Safe straight-line last-use move: `a` is a local whose only use is the move,
#    dead after -> b1 MUST be marked.
def f_safe -> int {
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
#    Plain local: an `own` source re-read after the call is E1301 and cannot compile.
def f_callarg -> int {
    a: Box = Box(v=1);
    take(a);
    b3 = a;
    return take(b3);
}

# 4. Source stored into a field (escapes) -> disqualified -> b4 NOT.
#    Plain local: an `own` source re-read after the field store cannot compile.
def f_fieldstore -> int {
    a: Box = Box(v=1);
    h = Holder(inner=Box());
    h.inner = a;
    b4 = a;
    return take(b4);
}

# 5. Source captured by a closure -> disqualified -> b5 NOT.
def f_closure -> int {
    a: own Box = Box(v=1);
    g = lambda { a; };
    b5 = a;
    return take(b5);
}

# 6. Source captured by a concurrent payload -> disqualified -> b6 NOT.
#    The payload is a sendable str (a plain Box is not sendable, E1308, and an
#    `own` Box re-read after the capture is E1301); str is still RC-managed.
def f_concurrent -> int {
    a: str = "payload";
    flow consume(a) ;
    b6 = a;
    return consume(b6);
}

# 7. Source borrowed (`&a`, a non-alias use) -> disqualified -> b7 NOT.
def f_borrow -> int {
    a: own Box = Box(v=1);
    r: &Box = &a;
    b7 = a;
    return take(b7);
}

# 8. Loop hazard: `a` defined OUTSIDE the loop, moved inside with no redefinition.
#    A later use is reached via the back-edge, so `a` is live-out -> b8 NOT.
#    Plain local: an `own` local moved under a deeper loop is E1301 and cannot compile.
def f_loop_hazard(n: int) -> int {
    a: Box = Box(v=0);
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

# 10. Source is a method's receiver. `self` is the caller's reference, bound by
#     the call like a param, so moving it releases a reference the method never
#     owned -> b10 NOT. It walks up from `self` the way `UniNode.sym_tab` does.
obj Chain {
    has up: (Chain | None) = None;

    def top -> Chain {
        b10: (Chain | None) = self;
        while b10 is not None and b10.up is not None {
            b10 = b10.up;
        }
        if b10 is None {
            raise ValueError("a walk from `self` cannot end at None");
        }
        return b10;
    }
}
