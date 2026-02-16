# Safe call operator with subscript: ?[
with entry {
    items: list | None = None;
    val = items?[0];
    nested = items?[0]?[1];
}
