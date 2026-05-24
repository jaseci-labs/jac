"""Native fixture exercising the walrus operator `:=`.

Each function binds a name inside an expression and then reuses that
binding, verifying that the assignment side-effect and the produced
value are both correct.
"""

def walrus_in_if(x: int) -> int {
    # The binding `n` must outlive the condition and equal x * 2.
    if (n := x * 2) > 5 {
        return n + 1;
    }
    return n;
}

def walrus_in_while(limit: int) -> int {
    total: int = 0;
    i: int = 0;
    # `cur` is rebound on every iteration; the loop sums 0..limit-1.
    while (cur := i) < limit {
        total = total + cur;
        i = i + 1;
    }
    return total;
}

def walrus_value(a: int) -> int {
    # The walrus expression itself evaluates to the assigned value.
    y: int = (m := a + 10);
    return y + m;
}
