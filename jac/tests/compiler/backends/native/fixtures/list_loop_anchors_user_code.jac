"""Range loops whose bodies run user code that empties a list they index.

`shadowed` calls a function of its own named `min` and `nested` steps a
generator: each of them empties `xs` while the loop runs, so the next `xs[0]`
has to raise IndexError. Neither loop may read the list's header once up
front.
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


with entry {
    print(shadowed([5, 6]));
}
glob ys = [5, 6];
with entry {
    print(nested(ys, popper(ys)));
}
