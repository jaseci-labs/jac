obj Counter {
    has n: int = 0;

    def bump -> None {
        self.n += 1;
    }

    def peek -> int {
        return self.n;
    }
}

def parse_port(s: str) -> int {
    if len(s) == 0 {
        raise ValueError("empty port");
    }
    return int(s);
}

def load(s: str) -> int {
    return parse_port(s) + 1;
}

with entry {
    c = Counter();
    c.bump();
    print(c.peek());
}
