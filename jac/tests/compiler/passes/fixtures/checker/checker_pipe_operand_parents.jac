"""Every pipe form, with no errors, so the module is type checked and emitted."""

def add_one(x: int) -> int {
    return x + 1;
}

def add(a: int, b: int) -> int {
    return a + b;
}

glob forward: int = 5 |> add_one,
     forward_atomic: int = 5 :> add_one,
     backward: int = add_one <| 5,
     backward_atomic: int = add_one <: 5,
     spread: int = (2, 3) |> add,
     spread_backward: int = add <| (2, 3),
     chained: int = 5 |> add_one |> add_one;
