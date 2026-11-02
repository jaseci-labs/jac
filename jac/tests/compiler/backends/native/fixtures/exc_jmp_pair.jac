"""Exception frames armed and unwound many times, through every frame kind:
nested handlers, a re-raise through a caller, `finally`, a walker ability
and a generator. Each frame is armed with the non-signal-mask setjmp and
raised into with its matching longjmp; a mismatched pair corrupts the frame
state (Darwin's `longjmp` restores a mask `_setjmp` never saved)."""

node Cell {
    has v: int = 0;
}

walker Probe {
    has seen: int = 0;

    can visit_cell with Cell entry {
        if here.v < 0 {
            raise ValueError("negative cell");
        }
        self.seen += here.v;
    }
}

def inner(i: int) -> int {
    if i % 3 == 0 {
        raise KeyError("k");
    }
    if i % 3 == 1 {
        raise ValueError("v");
    }
    return i;
}

def middle(i: int) -> int {
    try {
        return inner(i);
    } except KeyError {
        return -1;
    }
}

def outer(i: int, log: list[str]) -> int {
    try {
        return middle(i);
    } except ValueError {
        return -2;
    } finally {
        if i < 3 {
            log.append(f"finally {i}");
        }
    }
}

def countdown(n: int) -> Iterator[int] {
    i = n;
    while True {
        yield i;
        if i == 0 {
            raise RuntimeError("done");
        }
        i -= 1;
    }
}

glob log: list[str] = [];

with entry {
    total = 0;
    for i in range(3000) {
        total += outer(i, log);
    }
    print("total", total);
    print(log);
    good = Cell(v=5) spawn Probe();
    print("probe", good.seen);
    caught = 0;
    for _ in range(1000) {
        try {
            Cell(v=-1) spawn Probe();
        } except ValueError as e {
            caught += 1;
        }
    }
    print("walker raises caught", caught);
}

glob got: list[int] = [];

with entry {
    try {
        for v in countdown(3) {
            got.append(v);
        }
    } except RuntimeError as e {
        print("generator", got, e);
    }
}
