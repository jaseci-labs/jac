"""Pipe atomic expressions: Atomic forward pipe operator (:>) for chaining."""

with entry {
    # Atomic forward pipe :> (higher precedence than |>)
    "Hello" :> print;

    # Chained atomic pipes
    "Test" :> type :> print;

    # Atomic pipe with lambdas for function composition
    result = 5 :> (lambda  x: int: x * 2) :> (lambda  x: int: x + 10);
    print(result);
}
