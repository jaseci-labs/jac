"""The leaf-frame unwind fixture with an RC live-object dump at exit."""

obj Item {
    has v: int = 0,
        tag: str = "";
}

glob TABLE: list[Item | None] = [];

def lookup(i: int) -> Item {
    it = TABLE[i];
    if it is None {
        raise ValueError(f"empty slot {i}");
    }
    if it.v < 0 {
        raise ValueError(f"bad {it.tag}");
    }
    return it;
}

def make(v: int) -> Item {
    it = Item(v=v, tag=f"made {v}");
    if v < 0 {
        raise ValueError(f"bad {it.tag}");
    }
    return it;
}

def check(it: Item) -> int {
    if it.v > 100 {
        raise ValueError(f"too big {it.v}");
    }
    return it.v;
}

def keep(i: int) -> int {
    it = TABLE[i];
    if it is None {
        return -1;
    }
    return check(it) + 1;
}

def guard(i: int) -> int {
    try {
        return lookup(i).v;
    } except ValueError {
        return -100;
    } except IndexError {
        return -200;
    }
}

def run -> int {
    TABLE.append(Item(v=1, tag="one"));
    TABLE.append(None);
    TABLE.append(Item(v=-5, tag="minus"));
    TABLE.append(Item(v=500, tag="big"));
    total = 0;
    errors: list[str] = [];
    for r in range(40) {
        for i in range(5) {
            try {
                total += lookup(i).v;
            } except ValueError as e {
                errors.append(str(e));
            } except IndexError {
                errors.append("index");
            }
            try {
                total += make(i - 2).v;
            } except ValueError as e {
                errors.append(str(e));
            }
            try {
                total += keep(i);
            } except ValueError as e {
                errors.append(str(e));
            } except IndexError {
                errors.append("index");
            }
            total += guard(i);
        }
    }
    TABLE.clear();
    return total * 1000 + len(errors);
}

with entry {
    print(run());
    __rc_collect_cycles();
    __rc_debug_enable();
}
