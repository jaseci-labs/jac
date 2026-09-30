"""An `obj` deriving from Exception constructs through its field initializer."""

obj Bare(Exception) {}

obj Named(Exception) {
    has label: str = "";
}

obj Coded(Exception) {
    has code: int = 0;
}

obj Sub(Coded) {}

with entry {
    a = Bare("any message");
    b = Named("a label");
    c = Coded(code=3);
    d = Coded("not a code");
    e = Sub("not a code either");
    f = Sub(code=1);
    print(a, b, c, d, e, f);
}
