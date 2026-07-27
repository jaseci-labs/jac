obj Buffer {
    has n: int = 0;
}

def seed(r: &Region) -> Buffer {
    in r {
        x = Buffer();
        return x;
    }
}
