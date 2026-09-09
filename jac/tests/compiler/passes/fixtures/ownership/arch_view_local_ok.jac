obj Buffer { has n: int = 0; }
obj Cursor {
    has buf: &Buffer,
        pos: int = 0;

    def peek -> int { return self.buf.n + self.pos; }
}

def scan(b: &Buffer) -> int {
    c = Cursor(buf=b);
    return c.peek();
}

with entry {
    b: own Buffer = Buffer(n=4);
    print(scan(&b));
}
