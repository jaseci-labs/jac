obj Acc {
    has hi: int = 0,
        lo: int = 0;
}

def combine(a: own Acc, b: own Acc) -> Acc {
    return Acc(hi=a.hi + b.hi, lo=a.lo + b.lo);
}

def churn(n: int) -> int {
    total: own Acc = Acc(hi=0, lo=0);
    i = 0;
    while i < n {
        step: own Acc = Acc(hi=i, lo=i * 2);
        # `total` is moved into combine, then rebound to the fresh result;
        # it is live again on the next iteration -- no use-after-move.
        total = combine(total, step);
        i = i + 1;
    }
    return total.hi + total.lo;
}
