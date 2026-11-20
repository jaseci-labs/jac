obj Counter {
    has n: int = 0;

    def inc { self.n += 1; }
}

with entry {
    c: imm Counter = Counter();
    c.inc();
}
