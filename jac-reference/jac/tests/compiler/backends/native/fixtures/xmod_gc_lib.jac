obj Pool {
    has vals: list[float] = [],
        count: int = 0;
}

def pool_new -> Pool {
    p: own Pool = Pool();
    for i in range(4) {
        p.vals.append(0.0);
    }
    return p;
}

def pool_set(p: &mut Pool, i: int, v: float) {
    p.vals[i] = v;
    p.count += 1;
}

def pool_sum(p: &Pool) -> float {
    s = 0.0;
    for i in range(4) {
        s += p.vals[i];
    }
    return s;
}
