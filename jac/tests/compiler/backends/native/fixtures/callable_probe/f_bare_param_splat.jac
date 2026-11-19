obj T {
    has v: int = 0;

    def bump(n: int) -> None {
        self.v = self.v + n;
    }
}

def calls(f: Callable, a: list[any]) -> None {
    f(*a);
}

with entry {
    t = T();
    calls(t.bump, [2]);
    print(t.v);
}
