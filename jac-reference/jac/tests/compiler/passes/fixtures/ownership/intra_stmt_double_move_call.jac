obj Buffer { has n: int = 0; }

def use2(x: Buffer, y: Buffer) -> None {}

with entry {
    a: own Buffer = Buffer();
    use2(a, a);
}
