"""Bound methods used as values."""

def apply_one(f: Callable[[int], int], x: int) -> int {
    return f(x);
}

def apply_all(xs: list[int], f: Callable[[int], int]) -> list[int] {
    return [f(x) for x in xs];
}

obj Pass {
    has k: int = 3;

    def tr(x: int) -> int {
        return x * self.k;
    }

    def run -> int {
        f = self.tr;
        return apply_one(self.tr, 5) + f(2) + sum(apply_all([1, 2, 3], self.tr));
    }
}

obj Scaled(Pass) {
    override def tr(x: int) -> int {
        return x * self.k + 1;
    }
}

def passed_as_argument -> int {
    return Pass().run() + Pass(k=10).run();
}

def dispatches_to_override -> int {
    p: Pass = Scaled(k=2);
    g = p.tr;
    return g(10);
}

def sees_receiver_changes -> int {
    p = Pass(k=2);
    f = p.tr;
    p.k = 7;
    return f(1);
}

def stored_and_called_later -> int {
    fs: list[Callable[[int], int]] = [Pass(k=2).tr, Scaled(k=3).tr];
    return fs[0](5) + fs[1](5);
}
