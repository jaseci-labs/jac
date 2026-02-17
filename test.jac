class UniNode {}

class String(UniNode) {
    has strings: list[str];
}

class Int(UniNode) {
    has value: int;
}

with entry {
    expr: UniNode | None;
    if isinstance(expr, String) {
        for s in expr.strings {
            print("String:", s);
        }
        print("Got a list of strings:", expr.strings);
    } elif isinstance(expr, Int) {
        print("Integer value:", expr.value);
        print("Got an integer");
    } else {
        print("Got something else or nothing");
    }
}
