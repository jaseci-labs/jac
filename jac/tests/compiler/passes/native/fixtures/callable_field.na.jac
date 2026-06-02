"""Native fixture: function-pointer (`Callable`) stored in a struct field,
called indirectly through the field — including a list of such structs iterated
and dispatched (the shape the OSP kernel's dispatch slots rely on)."""

obj Op {
    has tag: int,
        fn: Callable[([int], int)];
}

def double(x: int) -> int {
    return x * 2;
}

def negate(x: int) -> int {
    return 0 - x;
}

def call_one(x: int) -> int {
    o = Op(tag=1, fn=double);
    return o.fn(x);
}

def dispatch_all(x: int) -> int {
    ops: list[Op] = [Op(tag=1, fn=double), Op(tag=2, fn=negate)];
    total = 0;
    for o in ops {
        total = total + o.fn(x);
    }
    return total;
}
