obj Buffer {
    has n: int = 0;
}

obj Wrap {
    has inner: (Buffer | None) = None;
}

def run {
    in Region() {
        x = Buffer();
        w = Wrap(inner=x);
        print(w.inner is x);
    }
}
