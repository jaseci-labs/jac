"""Native fixture exercising the pipe-forward operator `|>`.

`lhs |> f` desugars to `f(lhs)`, and a tuple lhs spreads into multiple
arguments: `(a, b) |> f` -> `f(a, b)`.
"""

def inc(x: int) -> int {
    return x + 1;
}

def add(a: int, b: int) -> int {
    return a + b;
}

def pipe_single(n: int) -> int {
    # n |> inc  ==  inc(n)
    return n |> inc;
}

def pipe_chain(n: int) -> int {
    # left-associative: (n |> inc) |> inc  ==  inc(inc(n))
    return n |> inc |> inc;
}

def pipe_tuple(a: int, b: int) -> int {
    # (a, b) |> add  ==  add(a, b)
    return (a, b) |> add;
}
