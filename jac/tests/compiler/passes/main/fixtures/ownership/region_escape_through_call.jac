obj Buffer {
    has n: int = 0;
}

def wrap(b: Buffer) -> Buffer {
    return b;
}

def make -> Buffer {
    in Region() {
        x = Buffer();
        return wrap(x);
    }
}
