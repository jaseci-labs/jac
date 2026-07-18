obj Buffer { has n: int = 0; }

def use2(x: Buffer, y: Buffer) -> None {}

with entry {
    a: own Buffer = Buffer();
    e1: &mut Buffer = &mut a;
    e2: &mut Buffer = &mut a;
    use2(e1, e2);
}
