obj Token {
    has kind: int,
        weight: int;

    def init(k: int, w: int) {
        self.kind = k;
        self.weight = w;
    }

    def score() -> int {
        return self.kind * 10 + self.weight;
    }
}

def lib_make(k: int, w: int) -> Token {
    return Token(k, w);
}
