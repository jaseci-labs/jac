obj Buffer {
    has n: int = 0;
}

glob hot: list[Buffer] = [];

def sink(b: Buffer) {
    hot.append(b);
}

def run {
    r: own Region = Region();
    s = Buffer();
    in r {
        b = Buffer();
        s = b;
    }
    sink(s);
}
