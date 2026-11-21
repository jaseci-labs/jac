"""Ownership states in Callable positions: declared intent, composed consumption."""

obj Buffer {
    has n: int = 0;
}

def apply(f: Callable[[own Buffer], None], b: own Buffer) {
    f(b);
}

def sink(x: own Buffer) {
    print(x.n);
}

with entry {
    a: own Buffer = Buffer(n=2);
    apply(sink, a);
    print(a.n);
}
