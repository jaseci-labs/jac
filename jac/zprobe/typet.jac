obj Base {
    has n: int = 0;
}

def make(cls: type[Base]) -> Base {
    return cls(1, 2, 3);
}

def make_kw(cls: type[Base]) -> Base {
    return cls(missing=1);
}
