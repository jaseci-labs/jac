"""E1301: appending a named own archetype binding moves it into the list."""

obj Box {
    has tag: int = 0;
}

def run -> int {
    xs: list[own Box] = [];
    b: own Box = Box(tag=1);
    xs.append(b);
    return b.tag;
}
