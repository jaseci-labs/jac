"""views in an enforced module: slices of borrowed and owned strings
used locally, and returned along the single-borrow elision subset --
all clean."""

def head(s: &str) -> str {
    return s[0:3];
}

def scan(s: &str) -> int {
    t = 0;
    for i in range(3) {
        piece = s[i:i + 2];
        t = t + len(piece);
    }
    return t;
}

def use_head(w: &str) -> int {
    h = head(w);
    return len(h);
}

glob w: own str = "abc" + "defg";

with entry {
    print(scan(&w));
    print(use_head(&w));
}

obj Tok {
    has buf: own str = "";

    def head -> str {
        return self.buf[0:2];
    }
}

def use_tok -> int {
    t = Tok(buf="abcdef");
    h = t.head();
    return len(h);
}
