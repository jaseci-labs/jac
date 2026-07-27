obj Buffer {
    has n: int = 0;
}

def run -> int {
    t = 0;
    in Region() {
        x = Buffer();
        x.n = 3;
        t = x.n;
    }
    return t;
}
