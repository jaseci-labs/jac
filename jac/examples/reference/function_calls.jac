"""Function calls: Positional, keyword, and mixed argument patterns."""

def compute(x: int, y: int, z: int = 10) -> tuple {
    return (x * y, y * z);
}

def variadic( *args: int , **kwargs: int)  -> int {
    return sum(args) + sum(kwargs.values());
}

# Positional arguments
glob r1 = compute(2, 3, 4),
     r2 = compute(x=5, y=6, z=7),
     r3 = compute(8, y=9, z=10),
     r4 = compute(2, 3),
     r5 = variadic(1, 2, 3, a=4, b=5);

with entry {
    print(r1, r2, r3, r4, r5);
}
# Keyword arguments

# Mixed positional and keyword

# Default parameter usage

# Unpacking with variadic
