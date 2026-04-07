"""No more `_` and `__` for access/visibility directives."""

obj MyObj {
    has:protect a: int;

    def:priv init(a: int) {
        self.a = a;
    }

    def:pub set_a(val: int) {
        self.a = val;
        ;
        ;
        ;
        ;
    }
}
