obj Buffer {
    has n: int = 0;
}

def make -> list {
    in Region() {
        x = Buffer();
        return [x];
    }
}
