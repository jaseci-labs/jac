"""A borrow may cross flow when the wait join lands before any conflicting use."""

obj Buffer {
    has n: int = 0;
}

def read_it(x: &Buffer) -> int {
    return x.n;
}

with entry {
    a: own Buffer = Buffer(n=5);
    h = flow read_it(&a) ;
    r = wait h ;
    a.n = 7;
    print(r + a.n);
}
