"""Generators, iterators and ranges passed as `any` iterate like Python."""

def walk(values: any) -> int {
    total = 0;
    for v in values {
        total += v;
    }
    return total;
}

def as_list(values: any) -> list[any] {
    return list(values);
}

def as_tuple(values: any) -> any {
    return tuple(values);
}

def total(values: any) -> any {
    return sum(values);
}

def gen_squares(n: int) -> Iterator[int] {
    for i in range(n) {
        yield i * i;
    }
}

with entry {
    print("for", walk((x * 2) for x in range(4)));
    print("list", as_list((x + 1) for x in range(3)));
    print("tuple", as_tuple((x * x) for x in range(4)));
    print("sum", total((x * x) for x in range(5)));
    print("gen", total(gen_squares(4)), as_list(gen_squares(3)));
    print("iter", walk(iter([5, 6, 7])), as_list(iter(["a", "b"])));
    print("range", walk(range(5)), as_list(range(2, 10, 3)), total(range(4)));
    print("range rev", as_tuple(range(5, 0, -2)), as_list(range(0)));
    words = (w.upper() for w in ["x", "y"]);
    print("strs", as_list(words), as_list(words));
}
