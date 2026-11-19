obj T {
    has v: int = 0;

    def bump(n: int) -> None {
        self.v = self.v + n;
    }

    def reset -> None {
        self.v = 0;
    }
}

obj Hook {
    has fn: Callable;

    def run -> None {
        self.fn();
    }
}

with entry {
    t = T(v=5);
    Hook(fn=t.reset).run();
    print(t.v);
}
