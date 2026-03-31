"""Impl file: list concatenation must produce array spread in JS."""

impl app.addItem -> None {
    item = await add_item("test");
    items = items + [item];
}
