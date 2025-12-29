"""Pipe back atomic expressions: Atomic backward pipe operator (<:) for right-to-left flow."""

# Atomic backward pipe <: (higher precedence than <|)
with entry {
    print <: "Hello";
}

# Mixing forward and backward atomic pipes
glob a = [2, 4, 5],
     b = [6, 7, 8],
     c = len <: a + b :> len,
     result = (lambda  x: int: x * 3) <: 10;

with entry {
    print(c, result);
}
# Backward atomic pipe with lambda
