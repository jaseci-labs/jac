obj Buffer { has n: int = 0; }

def use1(x: Buffer) -> None {}

with entry {
    a: imm Buffer = Buffer();
    flow use1(a);
}
