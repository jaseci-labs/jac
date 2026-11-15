"""A decorated and a generic function an importer reuses the names of."""
def keep(fn: any) -> any {
    return fn;
}

@keep
def glint(amount: int) -> int {
    return amount + 6;
}

def gleam[T](value: T) -> T {
    return value;
}

def plain(amount: int) -> int {
    return glint(amount) + gleam(amount);
}
