"""Functions in Jac."""

def factorial(n: int) -> int {
    if n == 0 {
        return 1;
    } else {
        return n * factorial(n - 1);
    }
}

def factorial_recount(n: int) -> int {
    count = 0;
    count += 1;
    count |> print;
    if n == 0 {
        return 1;
    } else {
        return n * factorial(n - 1);
    }
}
