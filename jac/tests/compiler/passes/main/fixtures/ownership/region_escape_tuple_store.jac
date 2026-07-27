obj Buffer {
    has n: int = 0;
}

def run {
    outer = None;
    in Region() {
        x = Buffer();
        outer = (x, );
    }
    print(outer);
}
