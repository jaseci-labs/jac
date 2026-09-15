obj Buffer {
    has n: int = 0;
}

def make -> list[any] {
    in Region() {
        x = Buffer();
        return [x];
    }
}
