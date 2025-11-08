def square(x: int) -> int {
    return (x ** 2);
}

with entry {
    number = 5;
    result = number |> square;
    print(result);
}
