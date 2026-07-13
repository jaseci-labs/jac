obj Buffer { has n: int = 0; }

def use1(x: Buffer) -> None {}

with entry {
    v: val Buffer = Buffer();
    x = v.n;
    use1(v);
}
