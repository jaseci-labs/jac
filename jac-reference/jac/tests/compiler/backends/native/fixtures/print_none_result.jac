glob calls: int = 0;

def bump {
    calls += 1;
}

def nothing -> None {
    return;
}

obj Counter {
    has n: int = 0;

    def tick {
        self.n += 1;
    }
}

with entry {
    print(bump());
    print("a", bump(), "b", nothing());
    c = Counter();
    print(c.tick(), c.n, calls);
    quiet = lambda (n: int) {
        a = n;
        b = n;
    };
    print(quiet(1));
}
