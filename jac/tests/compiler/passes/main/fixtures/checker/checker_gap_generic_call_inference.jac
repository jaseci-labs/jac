"""Test generic type parameter inference from constructor arguments."""

node Item {
    has value: int;
}

obj MyGeneric[T] {
    has data: T;

    def get_data -> T {
        return self.data;
    }
}

with entry {
    items: list[Item] = [Item(value=1), Item(value=2)];

    # enumerate(items) infers enumerate[Item]
    for (i, x) in enumerate(items) {
        wrong_x: str = x;  # Error: Item -> str
        print(x.value);
    }

    # MyGeneric(data=Item()) infers MyGeneric[Item]
    wrapper = MyGeneric(data=Item(value=42));
    result = wrapper.get_data();
    wrong_result: int = result;  # Error: Item -> int
    print(result.value);
}
