obj Buffer { has n: int = 0; }

def wrap(b: Buffer) -> Buffer { return b; }

def make() -> Buffer {
    region {
        x = Buffer();
        return wrap(x);
    }
}
