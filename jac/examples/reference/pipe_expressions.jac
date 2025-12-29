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

# Basic forward pipe: value |> function
glob result1 = 5 |> square,
     result2 = 3 |> add_ten |> double |> square,
     total = [1, 2, 3, 4, 5] |> sum,
     result3 = 10 |> (lambda  n: int: n * 3);

with entry {
    print(result1, result2, total, result3);
}
# Chained forward pipes

# Pipe with built-in functions

# Pipe to lambda
