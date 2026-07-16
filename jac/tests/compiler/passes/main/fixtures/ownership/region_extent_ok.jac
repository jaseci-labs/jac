obj Buffer {
    has n: int = 0;
}

def run {
    r: own Region = Region();
    x = Buffer();
    in r {
        b = Buffer();
        x = b;
    }
    print(x.n);
}
