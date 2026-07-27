obj Buffer {
    has n: int = 0;
}

def bad -> Buffer {
    r: own Region = Region();
    in r {
        x = Buffer();
        return x;
    }
}
