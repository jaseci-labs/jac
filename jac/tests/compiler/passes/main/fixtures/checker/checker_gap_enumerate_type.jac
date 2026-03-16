"""Test enumerate() type inference from iterable argument."""

node Item {
    has id: int;
}

with entry {
    items: list[Item] = [Item(id=1), Item(id=2), Item(id=3)];

    for (idx, item) in enumerate(items) {
        wrong_idx: str = idx;    # Error: int -> str
        wrong_item: int = item;  # Error: Item -> int
        print(item.id);
    }
}
