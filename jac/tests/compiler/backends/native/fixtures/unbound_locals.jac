"""Locals read before they are assigned, natively.

Each function reads a local on a path where no assignment has run yet. The
read raises UnboundLocalError with CPython's message, and the caller catches
it, exactly as on the Python backend. The reads that come after an
assignment on every path, and the loop-carried reads that only run once an
earlier iteration assigned the local, return the assigned values."""

glob limit: int = 4;

obj Box {
    has n: int = 0;
}

obj Tally {
    has seen: int = 0;

    def add(flag: bool) -> int;
}

impl Tally.add(flag: bool) -> int {
    if flag {
        extra = 3;
    }
    self.seen += extra;
    return self.seen;
}

def count(boxes: list[Box]) -> int {
    return len(boxes);
}

"""The original report: a typed list read before its first assignment."""
def total_of -> int {
    first = [Box(n=1)];
    total = count(first + later);
    later = [Box(n=2)];
    return total + len(later);
}

def early_scalar -> int {
    y = z + 1;
    z = 2;
    return y + z;
}

def picked(c: bool) -> int {
    if c {
        x = 5;
    }
    return x;
}

def named_len(c: bool) -> int {
    if c {
        s = "hello";
    }
    return len(s);
}

def aug_first -> int {
    total += 1;
    total = 0;
    return total;
}

def unpacked(c: bool) -> int {
    if c {
        (a, b) = (1, 2);
    }
    return a + b;
}

def walrus_seen(xs: list[int]) -> int {
    if len(xs) > 2 and (n := len(xs)) > 0 {
        return n;
    }
    return n;
}

def while_break(limit: int) -> int {
    i = 0;
    while i < limit {
        found = i * 3;
        i += 1;
        if i > 1 {
            break;
        }
    }
    return found;
}

"""A read in a loop body before the assignment below it: only the first
iteration would see it unbound, and the guard keeps that one out."""
def carried(n: int) -> list[int] {
    out: list[int] = [];
    for i in range(n) {
        if i > 0 {
            out.append(last);
        }
        last = i * i;
    }
    return out;
}

def trailing(n: int) -> Iterator[int] {
    for i in range(n) {
        if i > 0 {
            yield last;
        }
        last = i * 2;
    }
}

def early_yield(c: bool) -> Iterator[int] {
    if c {
        v = 7;
    }
    yield v;
}

def as_name_error -> str {
    try {
        v = w + 1;
        w = 3;
        return str(v);
    } except NameError as e {
        return "NameError: " + str(e);
    }
}

"""A `flow for` body runs in a function of its own and receives the locals it
reads by value, so those reads are left as they were."""
def summed(xs: list[int], c: bool) -> int {
    if c {
        k = 3;
    }
    total = 0;
    flow for v in &xs {
        total += v * k;
    }
    return total;
}

"""An assignment to a module glob rebinds the glob, so the read before it is
not a local read."""
def raised(c: bool) -> int {
    if c {
        return limit;
    }
    limit = 9;
    return limit;
}

"""Every read follows its assignment, so nothing here is guarded."""
def straight -> int {
    a = 1;
    b = a + 2;
    c = [a, b];
    return len(c) + b;
}

with entry {
    t = Tally();
    print(t.add(True));
    try {
        print(t.add(False));
    } except UnboundLocalError as e {
        print("caught", e);
    }
    try {
        print(total_of());
    } except UnboundLocalError as e {
        print("caught", e);
    }
    try {
        print(early_scalar());
    } except UnboundLocalError as e {
        print("caught", e);
    }
    print(picked(True));
    try {
        print(picked(False));
    } except UnboundLocalError as e {
        print("caught", e);
    }
    print(named_len(True));
    try {
        print(named_len(False));
    } except UnboundLocalError as e {
        print("caught", e);
    }
    try {
        print(aug_first());
    } except UnboundLocalError as e {
        print("caught", e);
    }
    print(unpacked(True));
    try {
        print(unpacked(False));
    } except UnboundLocalError as e {
        print("caught", e);
    }
    print(walrus_seen([1, 2, 3]));
    try {
        print(walrus_seen([1]));
    } except UnboundLocalError as e {
        print("caught", e);
    }
    print(while_break(5));
    try {
        print(while_break(0));
    } except UnboundLocalError as e {
        print("caught", e);
    }
    print(carried(4));
    print(list(trailing(4)));
    print(list(early_yield(True)));
    try {
        print(list(early_yield(False)));
    } except UnboundLocalError as e {
        print("caught", e);
    }
    print(as_name_error());
    print(summed([1, 2, 3], True));
    print(raised(True), raised(False), raised(True));
    print(straight());
}
