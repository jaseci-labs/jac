obj Buffer { has n: int = 0; }

def make() -> Buffer {
    region {
        x = Buffer();
        return x;
    }
}
