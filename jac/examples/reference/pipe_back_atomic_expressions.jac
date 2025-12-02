"""Pipe back atomic expressions: Atomic backward pipe operator (<:) for right-to-left flow."""

with entry {
    # Atomic backward pipe <: (higher precedence than <|)
    print <: "Hello";

    # Mixing forward and backward atomic pipes
    a = [2, 4, 5];
    b = [6, 7, 8];
    c = len <: a + b :> len;

    # Backward atomic pipe with lambda
    result = (lambda  x: int: x * 3) <: 10;

    print(c, result);
}
