"""E1305: a `lin` binding that reaches the end of its scope unconsumed."""

obj Handle {
    has id: int = 0;
}

def run -> int {
    h: lin Handle = Handle(id=1);
    return h.id;
}
