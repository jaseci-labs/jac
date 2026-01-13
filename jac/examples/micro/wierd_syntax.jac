"""No more `_` and `__` for access/visibility directives."""

obj MyObj {
    has:protect a: int;

    def:priv init(a: int) -> None {
        self.a = a;
    }

    def:pub set_a(val: int) -> None {
        self.a = val;
        ;
        ;
        ;
        ;
    }
}
