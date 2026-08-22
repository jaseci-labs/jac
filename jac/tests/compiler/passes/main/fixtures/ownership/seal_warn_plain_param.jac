"""Owned binding passed to an unannotated parameter: silent seal (W1312)."""

obj Buffer {
    has n: int = 0;
}

def sink(x: Buffer) {
    print(x.n);
}

with entry {
    a: own Buffer = Buffer(n=3);
    sink(a);
}
