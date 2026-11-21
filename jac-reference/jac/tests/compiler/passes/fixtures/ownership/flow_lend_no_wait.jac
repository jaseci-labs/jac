"""A borrow crossing flow with no join in sight stays E1308."""

obj Buffer {
    has n: int = 0;
}

def read_it(x: &Buffer) -> int {
    return x.n;
}

with entry {
    a: own Buffer = Buffer(n=5);
    flow read_it(&a) ;
    print(a.n);
}
