def churn(n: int) -> int {
    x: list[int] = [1];
    i: int = 0;
    while i < n {
        x.append(i);
        i += 1;
    }
    return len(x);
}

with entry {
    print(churn(100000000));  # jac:ignore[no-print]
}
