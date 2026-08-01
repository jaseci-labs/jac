def abs_val(x: int) -> int {
    if x < 0 {
        return 0 - x;
    }
    return x;
}

def max_val(a: int, b: int) -> int {
    if a > b {
        return a;
    }
    return b;
}

def factorial(n: int) -> int {
    result: int = 1;
    i: int = 1;
    while i <= n {
        result = result * i;
        i = i + 1;
    }
    return result;
}

def sum_to_n(n: int) -> int {
    total: int = 0;
    i: int = 1;
    while i <= n {
        total = total + i;
        i = i + 1;
    }
    return total;
}
