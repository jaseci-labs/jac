import sys;
import time;

def t_lit(n: int) -> int {
    acc = 0;
    i = 0;
    while i < n {
        t = (i, 1);
        acc += 1;
        i += 1;
    }
    return acc;
}

def t_idx(n: int) -> int {
    acc = 0;
    i = 0;
    while i < n {
        t = (i, 1);
        acc += t[0];
        i += 1;
    }
    return acc;
}

def t_app(n: int) -> int {
    stack: list[tuple[int, int]] = [];
    acc = 0;
    i = 0;
    while i < n {
        stack.append((i, 1));
        if len(stack) > 8 {
            stack.clear();
        }
        acc += 1;
        i += 1;
    }
    return acc;
}

def t_pop(n: int) -> int {
    stack: list[tuple[int, int]] = [];
    acc = 0;
    i = 0;
    while i < n {
        stack.append((i, 1));
        (a, p) = stack.pop();
        acc += a + p;
        i += 1;
    }
    return acc;
}

def make(i: int) -> list[int] {
    out: list[int] = [i, i + 1];
    return out;
}

def t_callret(n: int) -> int {
    acc = 0;
    i = 0;
    while i < n {
        xs = make(i);
        acc += xs[0];
        i += 1;
    }
    return acc;
}

with entry {
    mode = sys.argv[1] if len(sys.argv) > 1 else "t_lit";
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 1000000;
    t0 = time.perf_counter_ns();
    r = 0;
    if mode == "t_lit" {
        r = t_lit(n);
    } elif mode == "t_idx" {
        r = t_idx(n);
    } elif mode == "t_app" {
        r = t_app(n);
    } elif mode == "t_callret" {
        r = t_callret(n);
    } else {
        r = t_pop(n);
    }
    t1 = time.perf_counter_ns();
    print("probe:" + mode + ":" + str(r));
    print("ns=" + str(t1 - t0));
}
