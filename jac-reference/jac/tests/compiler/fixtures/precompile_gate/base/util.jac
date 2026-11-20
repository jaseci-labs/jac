obj Pair {
    has a: int = 0,
        b: int = 0;

    def total -> int {
        return self.a + self.b;
    }
}

def twice(x: int) -> int {
    return x * 2;
}

def label(p: Pair) -> str {
    return f"{p.a}+{p.b}";
}
