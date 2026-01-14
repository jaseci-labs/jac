"""Pipe atomic expressions: Atomic forward pipe operator (:>) for chaining."""

# Atomic forward pipe :> (higher precedence than |>)
with entry {
    "Hello" :> print;

    # Chained atomic pipes
    "Test" :> type :> print;
}

# Atomic pipe with lambdas for function composition
glob result = 5 :> (
         lambda x: int : x * 2
     ) :> (lambda x: int : x + 10);

with entry {
    print(result);
}
