"""File with bug related to cl js generation."""

obj Item {
    has b: int = 0;
}

glob setB = lambda (item: Item) -> None { item.b = 90; };
