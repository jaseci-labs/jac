def first[T](items: list[T]) -> T;

impl first[T](items: list[T]) -> T {
    picked: T = items[0];
    return picked;
}

obj Box;

impl Box.get -> int {
    return self.v + first([10, 20]);
}

impl Box {
    has v: int = 1;

    def get -> int;
}

with entry {
    print(first(["a", "b"]), Box().get());
}
