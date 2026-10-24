obj Part {
    has gen: int = 0;
}

obj Text(Part) {}

def lower(child: Text) -> int {
    if isinstance(child, Text) {
        return 1;
    } else {
        return child.gen;
    }
}
