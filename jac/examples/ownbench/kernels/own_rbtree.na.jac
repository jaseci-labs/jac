import sys;
import time;

obj Tree {
    has vals: list[int] = [],
        lefts: list[int] = [],
        rights: list[int] = [],
        reds: list[bool] = [],
        rooti: int = -1;
}

def nnew(t: &mut Tree, v: int) -> int {
    t.vals.append(v);
    t.lefts.append(-1);
    t.rights.append(-1);
    t.reds.append(True);
    return len(t.vals) - 1;
}

def is_red(t: &mut Tree, i: int) -> bool {
    if i == -1 {
        return False;
    }
    return t.reds[i];
}

def rot_left(t: &mut Tree, h: int) -> int {
    x = t.rights[h];
    t.rights[h] = t.lefts[x];
    t.lefts[x] = h;
    t.reds[x] = t.reds[h];
    t.reds[h] = True;
    return x;
}

def rot_right(t: &mut Tree, h: int) -> int {
    x = t.lefts[h];
    t.lefts[h] = t.rights[x];
    t.rights[x] = h;
    t.reds[x] = t.reds[h];
    t.reds[h] = True;
    return x;
}

def flip(t: &mut Tree, h: int) {
    t.reds[h] = not t.reds[h];
    t.reds[t.lefts[h]] = not t.reds[t.lefts[h]];
    t.reds[t.rights[h]] = not t.reds[t.rights[h]];
}

def ins(t: &mut Tree, h: int, v: int) -> int {
    if h == -1 {
        return nnew(t, v);
    }
    if v < t.vals[h] {
        t.lefts[h] = ins(t, t.lefts[h], v);
    } elif v > t.vals[h] {
        t.rights[h] = ins(t, t.rights[h], v);
    }
    if is_red(t, t.rights[h]) and not is_red(t, t.lefts[h]) {
        h = rot_left(t, h);
    }
    if is_red(t, t.lefts[h]) and is_red(t, t.lefts[t.lefts[h]]) {
        h = rot_right(t, h);
    }
    if is_red(t, t.lefts[h]) and is_red(t, t.rights[h]) {
        flip(t, h);
    }
    return h;
}

def insert(t: &mut Tree, v: int) {
    t.rooti = ins(t, t.rooti, v);
    t.reds[t.rooti] = False;
}

def contains(t: &mut Tree, v: int) -> bool {
    i = t.rooti;
    while i != -1 {
        if v == t.vals[i] {
            return True;
        } elif v < t.vals[i] {
            i = t.lefts[i];
        } else {
            i = t.rights[i];
        }
    }
    return False;
}

def checksum(t: &mut Tree) -> int {
    stack: list[int] = [];
    digest = 0;
    rank = 0;
    i = t.rooti;
    while i != -1 or len(stack) > 0 {
        while i != -1 {
            stack.append(i);
            i = t.lefts[i];
        }
        i = stack.pop();
        rank += 1;
        digest = (digest * 31 + t.vals[i] * rank) % 1000000007;
        i = t.rights[i];
    }
    return digest;
}

def run_round(n: int, seed: int) -> int {
    t: own Tree = Tree();
    x = seed;
    for i in range(n) {
        x = (x * 1103515245 + 12345) % 2147483648;
        insert(&mut t, x % (n * 4));
    }
    hits = 0;
    x = seed + 3;
    for i in range(n * 2) {
        x = (x * 1103515245 + 12345) % 2147483648;
        if contains(&mut t, x % (n * 4)) {
            hits += 1;
        }
    }
    return (checksum(&mut t) + hits) % 1000000007;
}

def run(n: int, reps: int) -> int {
    total = 0;
    for r in range(reps) {
        total = (total + run_round(n, r + 1)) % 1000000007;
    }
    return total;
}

with entry {
    n = 20000;
    if len(sys.argv) > 1 {
        n = int(sys.argv[1]);
    }
    reps = 5;
    if len(sys.argv) > 2 {
        reps = int(sys.argv[2]);
    }
    t0 = time.perf_counter_ns();
    total = run(n, reps);
    t1 = time.perf_counter_ns();
    print("rbtree:" + str(total));
    print("ns=" + str(t1 - t0));
}
