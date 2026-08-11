"""Explicit managed() at the call site: the seal is loud already, no warning."""

obj Buffer {
    has n: int = 0;
}

def sink(x: Buffer) {
    print(x.n);
}

with entry {
    a: own Buffer = Buffer(n=3);
    sink(managed(a));
}
