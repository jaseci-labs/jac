obj T {
    has v: int = 0;

    def bump(n: int) -> None {
        self.v = self.v + n;
    }
}

with entry {
    t = T();
    f: Callable = t.bump;
    try {
        f();
    } except TypeError as e {
        print("TypeError");
    }
    print(t.v);
}
