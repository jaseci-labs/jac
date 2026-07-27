"""Typed disconnect `a del ->:E:-> b` -- regression for the runtime
`disconnect(filter=...)` kwarg (previously emitted as `filter_on=`)."""

node N {
    has v: int = 0;
}

edge E {}

edge F {}

with entry {
    a = N(v=1);
    b = N(v=2);
    root ++> a;
    a +>:E:+> b;
    a +>:F:+> b;
    print("edges:", len([edge a -->]));
    a del ->:E:-> b;          # typed disconnect: drops only the E edge
    print("after E disconnect:", len([a ->:E:-> b]));
    print("F survives:", len([a ->:F:-> b]));
    b del <-:F:<- a;          # non-OUT typed disconnect (dir= kwarg)
    print("after F disconnect:", len([a ->:F:-> b]));
}
