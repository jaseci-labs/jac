obj Buffer {
    has n: int = 0;
}

glob hot: list[any] = [];

def sink(b: Buffer) {
    hot.append(b);
}

def run {
    in Region() {
        x = Buffer();
        sink(x);
    }
}
