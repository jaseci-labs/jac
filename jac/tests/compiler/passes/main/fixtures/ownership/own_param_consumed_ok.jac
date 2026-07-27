obj Buffer { has n: int = 0; }

def relay(p: own Buffer) -> Buffer {
    return p;
}

with entry {
    a: own Buffer = Buffer();
    r = relay(a);
}
