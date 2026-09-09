obj Buf {
    has data: list[int] = [];

    def push(v: int) { self.data.append(v); }
    def push_twice(v: int) { self.push(v); self.push(v); }
}

def read(b: &Buf) -> int { return len(b.data); }

with entry {
    b: own Buf = Buf();
    r: &Buf = &b;
    b.push_twice(2);
    print(read(r));
}
