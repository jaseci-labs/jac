def double(x: int) -> int {
    return (x * 2);
}

with entry {
    number = 5;
    result = double <| number;
    print(result);
}
