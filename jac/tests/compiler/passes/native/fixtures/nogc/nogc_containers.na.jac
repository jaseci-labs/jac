"""Owned-container matrix under headerless codegen: list/dict/set of scalars
x create/append/index/iterate/overwrite/drop."""

def run_lists -> int {
    xs = [1, 2, 3];
    xs.append(4);
    xs[0] = 9;
    total = 0;
    for v in xs {
        total += v;
    }
    return total;
}

def run_dicts -> int {
    d = {1: 10, 2: 20};
    d[3] = 30;
    d[1] = 11;
    total = 0;
    for k in d.keys() {
        total += d[k];
    }
    return total;
}

def run_sets -> int {
    s = {1, 2, 3};
    s.add(4);
    total = len(s);
    if 4 in s {
        total += 10;
    }
    if 9 in s {
        total += 100;
    }
    return total;
}

with entry {
    print(run_lists());
    print(run_dicts());
    print(run_sets());
}
