"""Returning a `lin` binding consumes it; the caller's binding takes over."""

obj Handle {
    has id: int = 0;
}

def open_one(id: int) -> own Handle {
    h: lin Handle = Handle(id=id);
    return h;
}
