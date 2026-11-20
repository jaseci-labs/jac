obj Buffer {
    has n: int = 0;
}

def widen(r: &Region, frontier: Buffer) {
    in r {
        frontier.n = 2;
    }
}

def run {
    r: own Region = Region();
    s = Buffer();
    in r {
        b = Buffer();
        s = b;
    }
    widen(&r, s);
}
