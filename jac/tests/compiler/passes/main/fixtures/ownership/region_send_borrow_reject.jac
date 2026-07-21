obj Buffer {
    has n: int = 0;
}

def consume(r: Region) -> int {
    return 1;
}

def run {
    r: own Region = Region();
    s = Buffer();
    in r {
        b = Buffer();
        s = b;
    }
    h = flow consume(r);
    wait h;
    print(s.n);
}
