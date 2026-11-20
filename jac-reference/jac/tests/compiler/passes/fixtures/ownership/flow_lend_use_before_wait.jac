"""Touching the lent owner between flow and wait stays E1308."""

obj Buffer {
    has n: int = 0;
}

def read_it(x: &Buffer) -> int {
    return x.n;
}

with entry {
    a: own Buffer = Buffer(n=5);
    h = flow read_it(&a) ;
    a.n = 7;
    r = wait h ;
    print(r);
}
