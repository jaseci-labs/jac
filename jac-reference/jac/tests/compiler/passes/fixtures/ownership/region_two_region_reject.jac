obj Buffer {
    has n: int = 0;
}

def bad(a: &Region, b: &Region) -> Buffer {
    in a {
        x = Buffer();
        return x;
    }
}
