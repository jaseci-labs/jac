obj Buffer { has n: int = 0; }

def first(p: &Buffer) -> Buffer {
    return p;
}

with entry {
    a: own Buffer = Buffer();
    r = first(&a);
    take_final(a);
}

def take_final(x: Buffer) -> None {}
