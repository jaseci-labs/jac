obj Buffer { has n: int = 0; }

def make() -> Buffer {
    a: own Buffer = Buffer();
    return a;
}

with entry {
    r = make();
}
