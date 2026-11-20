"""Owned binding passed to an own parameter: intentional transfer, no warning."""

obj Buffer {
    has n: int = 0;
}

def take(x: own Buffer) {
    print(x.n);
}

with entry {
    a: own Buffer = Buffer(n=3);
    take(a);
}
