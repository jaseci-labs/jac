obj Items {
    has data: list[str] = [];
}

obj Container {
    has items: Items | None = None;
}

def comprehension_in_true_branch(c: Container) -> list[str] {
    return [x for x in c.items.data] if c.items else [];
}
