"""First-class iterator values in generic positions (#7626 B4).

JacIter is type-erased, so iterator values should flow through
monomorphized signatures, containers, and adapters over passed-in
iterators; the per-site element type comes from the checker. These pin
the shapes #6403 deferred.
"""

def gen_nums(n: int) -> Iterator[int] {
    i = 0;
    while i < n {
        yield i;
        i += 1;
    }
}

def take2[T](it: Iterator[T]) -> list[T] {
    out: list[T] = [];
    c = 0;
    for x in it {
        out.append(x);
        c += 1;
        if c == 2 {
            break;
        }
    }
    return out;
}

def use_take2 -> int {
    r = take2(gen_nums(5));
    return r[0] * 10 + r[1];
}

def stored_iter -> int {
    its: list[Iterator[int]] = [gen_nums(3)];
    t = 0;
    for x in its[0] {
        t += x;
    }
    return t;
}

def adapter_over_param(it: Iterator[int]) -> int {
    t = 0;
    for v in map(lambda (x: int) -> int { x + 1; }, it) {
        t += v;
    }
    return t;
}

def use_adapter -> int {
    return adapter_over_param(gen_nums(3));
}
