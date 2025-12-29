"""Pipe back expressions: Backward pipe operator (<|) for right-to-left function application."""

def double(x: int) -> int {
    return x * 2;
}

def triple(x: int) -> int {
    return x * 3;
}

def add_five(x: int) -> int {
    return x + 5;
}

# Basic backward pipe: function <| value
glob result1 = double <| 5,
     result2 = add_five <| 10,
     result3 = (lambda  n: int: n * 3) <| 10,
     total = sum <| [1, 2, 3, 4, 5],
     temp = double <| 2,
     result4 = triple <| temp;

with entry {
    print(result1, result2, result3, total, result4);
}
# Backward pipe with lambda

# Backward pipe with built-in functions

# Multiple operations (separate statements)
