obj Buffer {
    has n: int = 0;
}

def run {
    in Region() {
        x = Buffer();
        x.n = 1;
        print(x.n);
    }
}
