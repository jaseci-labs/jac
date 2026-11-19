"""The same list default with and without `:=`, under headerless nogc."""

obj Plain {
    has vals: list[int] = [1];
}

obj Walrused {
    has vals: list[int] = (saved := [1]);
}

def plain_len -> int {
    p: own Plain = Plain();
    return len(p.vals);
}

def walrus_len -> int {
    w: own Walrused = Walrused();
    return len(w.vals);
}
