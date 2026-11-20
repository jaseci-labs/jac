"""Dependency for postinit_inherited_xmod_main (#8090): mirrors the unitree
`ElseIf(IfStmt)` shape -- `Mid` has three bases and carries the postinit,
`Leaf(Mid)` overrides methods but declares no postinit of its own, so a
`Leaf()` in an importing module must run `Mid.__post_init__` through the
inherited chain."""

obj BaseA {
    has a: int = 1;

    def touch() -> int {
        return self.a;
    }
}

obj BaseB {
    has b: int = 2;
}

obj BaseC {
    has c: int = 3;

    def touch() -> int {
        return self.c;
    }
}

obj Mid(BaseA, BaseB, BaseC) {
    has m: int = 0;

    def touch() -> int {
        return self.m;
    }

    def postinit {
        self.m = 42;
    }
}

obj Leaf(Mid) {
    def touch() -> int {
        return self.m + 1;
    }
}
