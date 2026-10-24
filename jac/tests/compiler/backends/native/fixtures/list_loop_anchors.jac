"""Range loops over lists whose headers are read once before the loop.

`axpy`, `copy_into`, `reverse` and `matmul` index lists in loops that cannot
change a list header, so their element reads and writes use the length and
data pointer read before the loop. The rest must not: `grow` appends in the
loop, `rebind` reassigns the list it indexes, `negative` indexes from the end
(the old path wraps it), `out_of_range` runs past the end and must raise the
same IndexError, and `unset` indexes a list that is still None when its loop
runs zero times.
"""

def axpy(y: list[float], x: list[float], a: float) -> None {
    for j in range(len(y)) {
        y[j] += a * x[j];
    }
}

def copy_into(dst: list[int], src: list[int]) -> None {
    for j in range(len(dst)) {
        dst[j] = src[j];
    }
}

def reverse(xs: list[int]) -> None {
    n = len(xs);
    for j in range(n // 2) {
        t = xs[j];
        xs[j] = xs[n - 1 - j];
        xs[n - 1 - j] = t;
    }
}

def matmul(a: list[list[float]], b: list[list[float]]) -> list[list[float]] {
    n = len(a);
    p = len(b[0]);
    c: list[list[float]] = [];
    for _ in range(n) {
        c.append([0.0] * p);
    }
    for i in range(n) {
        ci = c[i];
        ai = a[i];
        for k in range(len(b)) {
            aik = ai[k];
            bk = b[k];
            for j in range(p) {
                ci[j] += aik * bk[j];
            }
        }
    }
    return c;
}

def grow(xs: list[int]) -> int {
    for j in range(5) {
        xs.append(xs[j] + 1);
    }
    return len(xs) * 100 + xs[-1];
}

def rebind(xs: list[int], ys: list[int]) -> int {
    cur = xs;
    total = 0;
    for j in range(4) {
        total += cur[j];
        cur = ys;
    }
    return total;
}

def swap_rebind(a: list[int], b: list[int]) -> int {
    total = 0;
    for j in range(4) {
        total += a[j];
        (a, b) = (b, a);
    }
    return total;
}

def negative(xs: list[int]) -> int {
    total = 0;
    for j in range(1, 4) {
        total += xs[-j] * j;
        xs[-j] = j;
    }
    return total * 1000 + xs[-1] * 100 + xs[-2] * 10 + xs[-3];
}

def out_of_range(xs: list[float]) -> str {
    try {
        for j in range(len(xs) + 2) {
            xs[j] += 1.0;
        }
    } except IndexError {
        return f"caught {xs[0]} {xs[-1]}";
    }
    return "no raise";
}

def unset(n: int) -> int {
    ys: list[int] | None = None;
    if n > 0 {
        ys = [n] * n;
    }
    total = 0;
    if ys is not None {
        zs: list[int] = ys;
        for j in range(n) {
            total += zs[j];
        }
    }
    return total;
}

with entry {
    y = [1.0 * (i % 5) for i in range(20)];
    x = [0.5 * i for i in range(20)];
    axpy(y, x, 2.0);
    print(y[:6], y[-1]);
    src = [i * i for i in range(12)];
    dst = [0] * 12;
    copy_into(dst, src);
    print(dst);
    r = list(range(9));
    reverse(r);
    print(r);
    m = matmul([[1.0, 2.0], [3.0, 4.0]], [[5.0, 6.0], [7.0, 8.0]]);
    print(m);
    print(grow([1, 2, 3, 4, 5]), rebind([1, 2, 3, 4], [10, 20, 30, 40]));
    print(swap_rebind([1, 2, 3, 4], [10, 20, 30, 40]));
    print(negative([1, 2, 3, 4, 5]), out_of_range([1.0, 2.0, 3.0]));
    print(unset(0), unset(3));
}
