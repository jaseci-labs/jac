"""An `obj` deriving from Exception constructs through its own init; one
without fields keeps BaseException's, and a subclass adding no fields
inherits its base's."""

obj Bare(Exception) {}

obj Named(Exception) {
    has label: str = "";

    def init(label: str = "") {
        self.label = label;
    }
}

obj Coded(Exception) {
    has code: int = 0;

    def init(code: int = 0) {
        self.code = code;
    }
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
