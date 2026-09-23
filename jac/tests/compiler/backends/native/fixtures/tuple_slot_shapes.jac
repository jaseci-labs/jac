"""Tuple locals holding references: nested literals, owned temporaries, rebinds."""

obj Res {
    has tag: int = 0;
}

def nested(i: int) -> int {
    t = (i, "two", (3, 4));
    return t[0] + t[2][1];
}

def owned_str(i: int) -> str {
    t = (1, str(i) + "x", 3);
    return t[1];
}

def with_list(i: int) -> int {
    t = (1, [i, 2], 3);
    return len(t[1]);
}

def rebind(i: int) -> int {
    t = (0, Res(tag=i));
    t = (1, Res(tag=i + 1));
    u = t;
    return u[1].tag + t[1].tag;
}

def ret_local(i: int) -> tuple[int, Res] {
    t = (i, Res(tag=i));
    return t;
}

def into_list(i: int) -> int {
    out: list[tuple[int, str]] = [];
    for k in range(3) {
        t = (k, str(k + i));
        out.append(t);
    }
    return len(out) + len(out[2][1]);
}

def unpacked(i: int) -> int {
    t = (i, Res(tag=i));
    (a, r) = t;
    return a + r.tag;
}

def early(i: int) -> int {
    for k in range(5) {
        t = (k, str(k));
        if k == i {
            break;
        }
    }
    return i;
}

def branchy(i: int) -> int {
    if i > 1 {
        t = (i, str(i));
        return len(t[1]);
    }
    return 0;
}

def run -> int {
    total = loop_rebind(4) + copied(2);
    for i in range(4) {
        total += nested(i);
        total += len(owned_str(i));
        total += with_list(i);
        total += rebind(i);
        rl = ret_local(i);
        total += rl[1].tag;
        total += into_list(i);
        total += unpacked(i);
        total += early(i);
        total += branchy(i);
    }
    return total;
}

def loop_rebind(n: int) -> int {
    t = (0, "start");
    for k in range(n) {
        t = (k, str(k) + "!");
    }
    return len(t[1]);
}

def copied(i: int) -> int {
    t = (i, [i, i + 1]);
    u = t;
    t = (0, [9]);
    return len(u[1]) + len(t[1]);
}

with entry {
    print(run());
    print(nested(3), owned_str(12), with_list(1), rebind(5));
    r = ret_local(7);
    print(r[0], r[1].tag, into_list(1), unpacked(2), early(2), branchy(3));
    print(loop_rebind(3), copied(1));
}
