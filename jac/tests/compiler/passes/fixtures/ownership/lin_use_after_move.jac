"""E1301: a `lin` binding stays affine; a read after its consuming move is an error."""

obj Handle {
    has id: int = 0;
}

def close(h: own Handle) -> None {
    print(h.id);
}

def run -> int {
    h: lin Handle = Handle(id=1);
    close(h);
    return h.id;
}
