"""E1305: a `lin` parameter that is only read is dropped unconsumed at return."""

obj Handle {
    has id: int = 0;
}

def peek(h: lin Handle) -> int {
    return h.id;
}
