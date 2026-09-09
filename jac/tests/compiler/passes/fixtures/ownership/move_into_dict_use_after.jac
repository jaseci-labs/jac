"""E1301: storing a named own archetype binding as a dict value moves it."""

obj Box {
    has tag: int = 0;
}

def run -> int {
    d: dict[str, own Box] = {};
    b: own Box = Box(tag=1);
    d["k"] = b;
    return b.tag;
}
