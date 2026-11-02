"""Range loops whose bodies run user code that empties a list they index.

`shadowed` calls a function of its own named `min` and `nested` steps a
generator: each of them empties `xs` while the loop runs, so the next `xs[0]`
has to raise IndexError. `grow_list` and `grow_bytes` grow the list or the
bytearray in place through another name (`alias += ...`), which can move its
buffer. `via_getter` reads a field whose getter pops the list. None of these
loops may read the list's header once up front.
"""

def min(xs: list[int]) -> int {
    xs.pop();
    return 0;
}

def shadowed(xs: list[int]) -> str {
    t = 0;
    try {
        for j in range(3) {
            t += min(xs);
            t += xs[0];
        }
    } except IndexError {
        return f"caught {t}";
    }
    return f"no raise {t}";
}

def popper(xs: list[int]) -> Iterator[int] {
    while len(xs) > 0 {
        xs.pop();
        yield 1;
    }
}

def nested(xs: list[int], it: Iterator[int]) -> str {
    t = 0;
    try {
        for j in range(2) {
            for v in it {
                t += xs[0] + v;
            }
        }
    } except IndexError {
        return f"caught {t}";
    }
    return f"no raise {t}";
}


obj Box {
    has xs: list[int] = [];
    has n: int { getter; }
}

impl Box.n.getter -> int {
    self.xs.pop();
    return len(self.xs);
}

def via_getter(b: Box, xs: list[int]) -> str {
    t = 0;
    try {
        for j in range(3) {
            t += b.n;
            t += xs[0];
        }
    } except IndexError {
        return f"caught {t}";
    }
    return f"no raise {t}";
}

def grow_list(xs: list[int]) -> int {
    alias = xs;
    total = 0;
    for j in range(3) {
        alias += [j, j, j, j];
        total += xs[0] * 10;
    }
    return total;
}

def grow_bytes(buf: bytearray) -> int {
    alias = buf;
    total = 0;
    for j in range(3) {
        alias += b"abcdefgh";
        total += buf[0] + len(buf);
    }
    return total;
}

with entry {
    print(shadowed([5, 6]));
}

glob ys = [5, 6];

with entry {
    print(nested(ys, popper(ys)));
    print(grow_list([5]), grow_bytes(bytearray(b"x")));
}

glob zs = [5, 6];
with entry {
    print(via_getter(Box(xs=zs), zs));
}
