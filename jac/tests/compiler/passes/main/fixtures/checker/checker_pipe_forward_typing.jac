"""Pipe operators must type as the equivalent function call."""

def add_one(x: int) -> int {
    return x + 1;
}

def add(a: int, b: int) -> int {
    return a + b;
}

def shout(s: str) -> str {
    return s + "!";
}

def takes_int(x: int) -> int {
    return x + 1;
}

glob r1: int = 5 |> add_one,
     r2: int = 5 :> add_one,
     r3: int = add_one <| 5,
     r4: int = add_one <: 5,
     r5: int = (2, 3) |> add,
     r6: int = add <| (2, 3),
     r7: str = "hi" |> shout |> shout,
     r8: str = shout <| "hi";

# Uncalled — kept out of `jac run` while the checker still walks the body.
def negative_case -> int {
    return "oops" |> takes_int;
}
