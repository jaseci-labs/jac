obj Buffer {
    has n: int = 0;
}

def run {
    in Region() {
        x = Buffer();
        items = [x];
        print(len(items));
    }
}
