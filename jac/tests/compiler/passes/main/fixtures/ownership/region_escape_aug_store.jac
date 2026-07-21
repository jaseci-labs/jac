obj Buffer {
    has n: int = 0;
}

glob hot: list[Buffer] = [];

def run {
    in Region() {
        x = Buffer();
        hot += [x];
    }
}
