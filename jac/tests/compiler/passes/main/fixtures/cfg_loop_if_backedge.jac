def use(items: list) -> str {
    tag = "";
    for item in items {
        if item == "x" {
            tag = item;
        }
    }
    return tag;
}
