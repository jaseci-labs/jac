obj Items {
    has data: list[str] = [];
}

obj Container {
    has items: Items | None = None;
}

def simple_attr_access(c: Container) -> list[str] {
    return c.items.data if c.items else [];
}
