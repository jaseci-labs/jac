"""A pack of the erased type parameter is a pointer list, so a by-value type
argument has no sound element slot. `Cell[int]` must be refused naming the
instantiation, exactly as an erased `has` field at a scalar argument is."""

obj Cell[T] {
    has name: str;

    def get(*fallback: T) -> T {
        return fallback[0];
    }
}

glob N: Cell[int] = Cell[int]("n");

def run_probe {
    print(N.get(7));
}

with entry {
    run_probe();
}
