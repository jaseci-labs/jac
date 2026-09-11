obj Foo {
    has label: str = "";
}

def use(items: list[any]) -> str {
    for item in items {
        if isinstance(item, Foo) {
            return item.label;
        }
    }
    return "";
}
