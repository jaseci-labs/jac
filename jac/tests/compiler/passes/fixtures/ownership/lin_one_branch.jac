"""E1305: a `lin` binding consumed on one branch only is unconsumed on the other."""

obj Handle {
    has id: int = 0;
}

def close(h: own Handle) -> None {
    print(h.id);
}

def run(flag: bool) -> None {
    h: lin Handle = Handle(id=1);
    if flag {
        close(h);
    }
}
