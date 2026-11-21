"""Suffix slices of fresh strings, consumed by builtins, list and set and
dict methods, list literals, index assignment, tuples and parameters: after
the work runs and the cycle collector sweeps, the RC debug build's
live-object dump at exit must be empty. Each shape repeats, so a per-use
imbalance (the view's root reference or the copy taken of it) shows up as
many leaked strings rather than one."""

def fresh(i: int) -> str {
    return "weapon_" + str(i);
}

obj Pack {
    has names: list[str] = [];
}

def fill(pack: Pack, kind: str) {
    pack.names.append(kind[7:]);
}

def round_trip(i: int) -> int {
    source = fresh(i);
    t = int(source[7:]) + len(str(source[7:]));
    items: list[str] = [];
    items.append(source[7:]);
    items.insert(0, source[7:]);
    view = source[7:];
    kept = [view, view];
    t += int(view) + len(kept);
    unique: set[str] = set();
    unique.add(source[7:]);
    table: dict[str, str] = {};
    table.setdefault("k", source[7:]);
    t += len(table.get("q", source[7:]));
    assigned: list[str] = ["?"];
    assigned[0] = source[7:];
    pair = (source[7:], i);
    pack = Pack();
    fill(pack, source);
    return t
        + len(items)
        + len(unique)
        + len(assigned[0])
        + len(pair[0])
        + len(pack.names);
}

with entry {
    total = 0;
    for i in range(50) {
        total += round_trip(i);
    }
    print(total);
    __rc_collect_cycles();
    __rc_debug_enable();
}
