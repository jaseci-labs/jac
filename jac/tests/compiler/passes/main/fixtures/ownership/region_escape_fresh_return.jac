obj Buffer {
    has n: int = 0;
}

def make -> Buffer {
    in Region() {
        return Buffer();
    }
}
