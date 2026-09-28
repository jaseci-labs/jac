"""Bounded append/read/pop churn against a loop-carried list.

Each iteration appends, reads one element back by index, and pops once the
list passes the bound, so the list stays resident and every loop iteration
re-touches the len/cap/data header. That is the shape where the native
backend now keeps the header fields in SSA values instead of re-loading
them through the header pointer each iteration.
"""

def churn(n: int) -> int {
    lst: list[int] = [];
    acc = 0;
    for i in range(n) {
        lst.append(i);
        acc += lst[i & 63];
        if len(lst) > 64 {
            acc += lst.pop();
        }
    }
    return acc + len(lst);
}

def churn_str(n: int) -> int {
    lst: list[str] = [];
    acc = 0;
    for i in range(n) {
        lst.append("x" + str(i));
        acc += len(lst[i & 63]);
        if len(lst) > 64 {
            acc += len(lst.pop());
        }
    }
    return acc + len(lst);
}
