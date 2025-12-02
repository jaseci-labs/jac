"""Pipe expressions: Forward pipe operator (|>) for function chaining."""

def square(x: int) -> int {
    return x ** 2;
}

def double(x: int) -> int {
    return x * 2;
}

def add_ten(x: int) -> int {
    return x + 10;
}

with entry {
    # Basic forward pipe: value |> function
    result1 = 5 |> square;

    # Chained forward pipes
    result2 = 3 |> add_ten |> double |> square;

    # Pipe with built-in functions
    total = [1, 2, 3, 4, 5] |> sum;

    # Pipe to lambda
    result3 = 10 |> (lambda  n: int: n * 3);

    print(result1, result2, total, result3);
}
