obj Counter {
    has n: int = 0;

    def inc { self.n += 1; }
}

def bump(c: &mut Counter) { c.inc(); }

with entry {
    c: own Counter = Counter();
    bump(&mut c);
    print(c.n);
}
