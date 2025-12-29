# Lexer tokens - Builtin type keywords

# These lexer tokens are used as type annotations
# They are keywords that represent builtin types
glob x: str = "string",
     y: int = 42,
     z: float = 3.14,
     lst: list = [1, 2, 3],
     tup: tuple = (1, 2),
     s: set = {1,2},
     d: dict = {"key": "value"},
     b: bool = True;

with entry {
    print(x, y, z, lst, tup, s, d, b);  # Note: These are tokenized specially so they can be used as types
}
# See builtin_types.jac for more comprehensive type usage examples
