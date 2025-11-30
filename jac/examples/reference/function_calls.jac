"""Function calls: Positional, keyword, and mixed argument patterns."""

def compute(x: int, y: int, z: int = 10) -> tuple {
    return (x * y, y * z);
}

def variadic( *args: int , **kwargs: int)  -> int {
    return sum(args) + sum(kwargs.values());
}

with entry {
    # Positional arguments
    r1 = compute(2, 3, 4);

    # Keyword arguments
    r2 = compute(x=5, y=6, z=7);

    # Mixed positional and keyword
    r3 = compute(8, y=9, z=10);

    # Default parameter usage
    r4 = compute(2, 3);

    # Unpacking with variadic
    r5 = variadic(1, 2, 3, a=4, b=5);

    print(r1, r2, r3, r4, r5);
}
