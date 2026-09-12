"""Generator arguments must infer their output independently of source items."""
obj Entry {
    has kind: str,
        annotation: str = "";
}
def:pub generator_bool_check -> int {
    values = [Entry(kind="function"), Entry(kind="class")];
    if not any(item.kind == "function" and not item.annotation for item in values) {
        return 1;
    }
    if all(item.kind == "function" and not item.annotation for item in values) {
        return 2;
    }
    if any(item.kind == "missing" for item in values) {
        return 3;
    }
    return 0;
}
