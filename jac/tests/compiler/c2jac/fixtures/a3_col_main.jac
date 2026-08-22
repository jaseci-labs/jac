import from a3_col_lib { Token as LibToken, lib_make }

obj Token {
    has line: int,
        col: int;

    def init(a: int, b: int) {
        self.line = a;
        self.col = b;
    }

    def score() -> int {
        return self.line + self.col * 100;
    }
}

def run_local() -> int {
    t: Token = Token(3, 4);
    return t.score();
}

def run_lib() -> int {
    t: LibToken = lib_make(2, 5);
    return t.score();
}

def run_mixed() -> int {
    a: Token = Token(1, 1);
    b: LibToken = LibToken(1, 1);
    return a.score() + b.score();
}
