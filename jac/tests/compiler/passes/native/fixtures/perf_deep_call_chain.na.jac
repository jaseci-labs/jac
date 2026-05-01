"""P-07: Deep call chain (200-level recursion).

A 200-level recursive function that passes a struct through each frame and
returns it.  Measures call overhead, scope setup cost, and — once RC-4 is
wired — the cost of scope-cleanup retain/release at each return.
Timing and RSS are measured externally by run_perf.sh via /usr/bin/time.
"""

obj Frame {
    has depth: int = 0;
    has acc: int = 0;
}

def recurse(f: Frame, limit: int) -> Frame {
    if f.depth >= limit {
        return f;
    }
    next: Frame = Frame(depth=f.depth + 1, acc=f.acc + f.depth);
    return recurse(next, limit);
}

with entry {
    # __rc_debug_enable();
    runs: int = 0;
    last_acc: int = 0;
    while runs < 5000 {
        start: Frame = Frame(depth=0, acc=0);
        result: Frame = recurse(start, 200);
        last_acc = result.acc;
        runs = runs + 1;
    }
    print("OK deep_call_chain acc =", last_acc);
}
