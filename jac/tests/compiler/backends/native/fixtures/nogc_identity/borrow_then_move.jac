"""An owned local moved after it was borrowed hands its payload to the new
owner exactly once: after a `&mut` call argument, after a `&` call argument,
after borrows inside a loop, after borrows of one of its fields, into an
existing binding, as an optional `own` local, and as an `own` parameter.
Headerless builds used to leave the source owning the payload too, so it was
freed at the source's last use while the new owner still pointed at it."""

obj Res {
    has tag: int = 0,
        n: int = 0;

    def drop {
        print("drop " + str(self.tag));
    }
}

obj Holder {
    has inner: own Res,
        label: str = "h";
}

def bump(r: &mut Res) {
    r.n += 1;
}

def peek(r: &Res) -> int {
    return r.n;
}

def mut_then_move {
    a = Res(tag=1);
    bump(&mut a);
    m = a;
    print("mut m.n=" + str(m.n));
}

def shared_then_move {
    a = Res(tag=2, n=5);
    print("peek " + str(peek(&a)));
    m: own Res = a;
    print("shared m.n=" + str(m.n));
}

def loop_then_move {
    a = Res(tag=3);
    for i in range(3) {
        bump(&mut a);
    }
    k = 0;
    while k < 2 {
        print("loop peek " + str(peek(&a)));
        k += 1;
    }
    m = a;
    print("loop m.n=" + str(m.n));
}

def field_then_move {
    h = Holder(inner=Res(tag=4));
    bump(&mut h.inner);
    print("field peek " + str(peek(&h.inner)));
    g = h;
    print("field g.inner.n=" + str(g.inner.n));
}

def move_into_existing {
    m = Res(tag=5);
    print("first m.tag=" + str(m.tag));
    a = Res(tag=6);
    bump(&mut a);
    m = a;
    print("existing m.tag=" + str(m.tag) + " m.n=" + str(m.n));
}

def optional_then_move {
    a: own Res | None = Res(tag=7, n=9);
    if a is not None {
        print("opt a.n=" + str(a.n));
    }
    m = a;
    if m is not None {
        print("opt m.n=" + str(m.n));
    }
}

def param_then_move(p: own Res) {
    bump(&mut p);
    m = p;
    print("param m.n=" + str(m.n));
}

with entry {
    mut_then_move();
    print("--");
    shared_then_move();
    print("--");
    loop_then_move();
    print("--");
    field_then_move();
    print("--");
    move_into_existing();
    print("--");
    optional_then_move();
    print("--");
    param_then_move(Res(tag=8));
    print("done");
}
