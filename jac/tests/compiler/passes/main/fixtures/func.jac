"""Functions in Jac."""

import from func2 { factorial as factorial }

def factorial_recount(n: int) -> int {
    count: str = 0;
    count += 1;
    count |> print;
    if n == 0 {
        return 1;
    } else {
        return n * factorial(n - 1);
    }
}

with entry {
    print(factorial(3));
}
