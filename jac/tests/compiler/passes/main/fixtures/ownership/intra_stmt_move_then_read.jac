obj Buffer { has n: int = 0; }

def take(x: Buffer) -> Buffer { return x; }

with entry {
    a: own Buffer = Buffer();
    b = [take(a), a];
}
