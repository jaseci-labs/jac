obj Buffer {
    has n: int = 0;
}

def consume(r: Region) -> int {
    return 1;
}

def run {
    r: own Region = Region();
    in r {
        x = Buffer();
        x.n = 1;
    }
    h = flow consume(r);
    wait h;
}
