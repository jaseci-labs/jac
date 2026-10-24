"""Frames that hold an owned local only across their own raises.

`lookup` and `make` bind an owned local and can raise while it holds a
reference, but call nothing that can raise once it is bound: they keep no
unwind record and release the local just before raising. `keep` holds its
local across a call that can raise and keeps its record. `guard` arms a
handler in a program that never enters a region.
"""

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

with entry {
    TABLE.append(Item(v=1, tag="one"));
    TABLE.append(None);
    TABLE.append(Item(v=-5, tag="minus"));
    TABLE.append(Item(v=500, tag="big"));
    total = 0;
}

glob errors: list[str] = [];
with entry {
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
    print(total, len(errors));
    print(",".join(errors[:14]));
    for it in TABLE {
        if it is not None {
            print(it.tag, it.v);
        }
    }
}
