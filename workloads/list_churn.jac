def churn(n: int) -> int {
    x: list[int] = [1];
    i: int = 0;
    s: int = 0;
    while i < n {
        x.append(i);
        s += x[i];
        i += 1;
    }
    return s + len(x);
}

with entry {
    print(churn(100000000));  # jac:ignore[no-print]
}
