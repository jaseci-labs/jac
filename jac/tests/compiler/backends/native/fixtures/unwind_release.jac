"""Raises that cross several frames holding lists, strings and objects."""

obj Holder {
    has items: list[int],
        name: str;

    def explode(n: int) -> int {
        tag = f"m{n}";
        extra = [tag, tag + "!"];
        if n % 2 == 0 {
            raise KeyError("method " + tag);
        }
        return len(extra) + len(self.items);
    }
}

def index_fail(n: int) -> int {
    data = [n, n * 2];
    label = f"idx{n}";
    return data[n + 5] + len(label);
}

def level3(n: int) -> int {
    s = f"tmp{n}";
    xs = [n, n + 1];
    h = Holder(items=[n], name=s);
    if n % 3 == 0 {
        raise ValueError("boom " + s);
    }
    if n % 3 == 1 {
        return h.explode(n) + index_fail(n);
    }
    return len(xs) + len(h.items) + index_fail(n);
}

def level2(n: int) -> int {
    t = "x" * 3 + str(n);
    ys = [t, t];
    try {
        return level3(n) + len(ys);
    } except KeyError as e {
        inner = [str(e), t];
        raise RuntimeError("wrapped " + inner[0]);
    }
}

def level1(n: int) -> int {
    zs: list[str] = [str(n)];
    total = 0;
    for k in range(2) {
        piece = f"{k}:{n}";
        total += len(piece);
    }
    return level2(n) + len(zs) + total;
}

def run -> int {
    caught = 0;
    for i in range(300) {
        try {
            level1(i);
        } except ValueError as e {
            caught += 1;
        } except IndexError as e {
            caught += 100;
        } except RuntimeError as e {
            caught += 10000;
        }
    }
    return caught;
}

with entry {
    print(run());
}
