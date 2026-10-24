def impl_total(n: int) -> int;

impl impl_total(n: int) -> int {
    total = 0;
    add = lambda (t: int) -> int { total = total + t; return total; };
    add(n);
    add(n);
    return total;
}

def inline_total(n: int) -> int {
    total = 0;
    add = lambda (t: int) -> int { total = total + t; return total; };
    add(n);
    add(n);
    return total;
}

with entry {
    print(impl_total(3), inline_total(3));
}
