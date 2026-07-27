obj Buffer { has n: int = 0; }

def sink(p: own Buffer) -> None {
    print("dropped");
}

with entry {
    a: own Buffer = Buffer();
    sink(a);
}
