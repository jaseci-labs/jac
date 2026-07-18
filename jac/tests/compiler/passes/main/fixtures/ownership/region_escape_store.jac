obj Box {
    has item: any = None;
}
obj Buffer {
    has n: int = 0;
}

def stash(b: Box) {
    in Region() {
        x = Buffer();
        b.item = x;
    }
}
