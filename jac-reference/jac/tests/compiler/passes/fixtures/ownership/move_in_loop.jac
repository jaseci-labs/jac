obj Buffer { has n: int = 0; }

def consume(x: Buffer) -> None {}

with entry {
    a: own Buffer = Buffer();
    i = 0;
    while i < 3 {
        consume(a);
        i += 1;
    }
}
