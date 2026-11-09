"""A nested function returned as `any` and called as a Callable leaks nothing.

Boxing the function allocates its closure; the box carries that ownership,
so each returned value is released once instead of retained again.
"""

def make_inc -> any {
    def inc(x: int) -> int {
        return x + 1;
    }
    return inc;
}

def run -> int {
    total = 0;
    for i in range(50) {
        f: Callable[[int], int] = make_inc();
        total += f(i);
    }
    return total;
}

with entry {
    print(run());
    __rc_collect_cycles();
    __rc_debug_enable();
}
