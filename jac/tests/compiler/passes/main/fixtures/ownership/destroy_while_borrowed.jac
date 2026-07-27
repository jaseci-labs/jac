obj Buffer { has n: int = 0; }

def use1(x: Buffer) -> None {}

with entry {
    v: &Buffer;
    if len("x") > 0 {
        a: own Buffer = Buffer();
        v = &a;
    }
    use1(v);
}
