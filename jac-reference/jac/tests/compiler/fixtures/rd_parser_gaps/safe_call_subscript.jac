# Safe call operator with subscript: ?[
with entry {
    items: list[any] | None = None;
    val = items?[0];
    nested = items?[0]?[1];
}
