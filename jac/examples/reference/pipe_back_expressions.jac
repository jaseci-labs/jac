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

with entry {
    # Basic backward pipe: function <| value
    result1 = double <| 5;
    result2 = add_five <| 10;

    # Backward pipe with lambda
    result3 = (lambda  n: int: n * 3) <| 10;

    # Backward pipe with built-in functions
    total = sum <| [1, 2, 3, 4, 5];

    # Multiple operations (separate statements)
    temp = double <| 2;
    result4 = triple <| temp;

    print(result1, result2, result3, total, result4);
}
