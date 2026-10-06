"""Locals a protected body writes before it raises, read after the longjmp.

Every function here arms a setjmp frame and is optimized: the handler, the
finally clause, a re-armed loop iteration and a resumed generator must see the
last value written to each local, not a copy the optimizer kept from the
arming.
"""

obj Box {
    has n: int = 0,
        tags: list[str] = [];
}

def check(x: int, limit: int) -> int {
    if x > limit {
        raise ValueError(f"at {x}");
    }
    return x + 1;
}

# Scalars, strings, objects and lists written in a loop inside the try.
def scalars -> str {
    total = 0;
    ratio = 1.5;
    flag = False;
    text = "";
    box = Box();
    items: list[int] = [];
    try {
        for i in range(10) {
            total += i;
            ratio = ratio * 2.0;
            flag = i % 2 == 1;
            text = text + str(i);
            box.n = i;
            box.tags.append(f"t{i}");
            items.append(i * 2);
            check(i, 3);
        }
    } except ValueError as err {
        text = text + "|" + str(err);
    } finally {
        total += 100;
    }
    return f"{total} {ratio} {flag} {text} {box.n} {len(box.tags)} {len(items)}";
}

# A finally clause that reads what the body wrote before the raise escapes.
def escaping(limit: int) -> int {
    seen = 0;
    try {
        for i in range(10) {
            seen = i;
            check(i, limit);
        }
    } finally {
        print(f"finally saw {seen}");
    }
    return seen;
}

def caller -> str {
    got = -1;
    stage = "start";
    try {
        stage = "calling";
        got = escaping(2);
        stage = "returned";
    } except ValueError {
        stage = stage + ":caught";
    }
    return f"{got} {stage}";
}

# A try re-armed on every iteration, with an accumulator written in the body
# and the handler, and a nested try that re-raises.
def rearmed -> int {
    acc = 0;
    for i in range(20) {
        step = i;
        try {
            acc += 1;
            step = step * 3;
            try {
                check(step, 30);
            } except ValueError {
                acc += 1000;
                raise;
            }
            acc += step;
        } except ValueError {
            acc += step;
        }
    }
    return acc;
}

# A with block whose body writes locals, then raises.
obj Guard {
    has log: list[str] = [];

    def __enter__ -> Guard {
        self.log.append("enter");
        return self;
    }

    def __exit__(kind: any, value: any, trace: any) -> bool {
        self.log.append("exit");
        return True;
    }
}

def guarded -> str {
    count = 0;
    guard = Guard();
    with guard as g {
        count = 5;
        g.log.append(f"count={count}");
        count = 7;
        check(count, 1);
        count = 9;
    }
    return f"{count} {','.join(guard.log)}";
}

# A generator that writes locals in a try around its yields, then raises.
def producer(n: int) -> Iterator[int] {
    made = 0;
    try {
        for i in range(n) {
            made += 1;
            yield i * 10;
            check(made, 3);
        }
    } except ValueError {
        made += 100;
        yield made;
    }
}

# A closure over a local the try body writes.
def closure -> int {
    base = 1;
    def add(x: int) -> int {
        return x + base;
    }
    try {
        base = 40;
        check(base, 10);
    } except ValueError {
        base = base + 2;
    }
    return add(0);
}

with entry {
    print(scalars());
    print(caller());
    print(rearmed());
    print(guarded());
    print([x for x in producer(10)]);
    print(closure());
}
