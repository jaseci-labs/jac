obj Buffer {
    has n: int = 0;
    def eat(x: Buffer) -> None {}
}

with entry {
    a: own Buffer = Buffer();
    a.eat(a);
}
