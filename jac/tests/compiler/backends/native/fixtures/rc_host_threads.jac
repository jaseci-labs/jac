"""Native functions a Python host calls from several threads at once.

The host's threads are not started by the native code, so no spawn site
switches refcount updates to atomic: the host side does, when it loads the
code (`__jac_shared_init` for a shared library, the JIT engine before it hands
out an address). `hammer` takes and drops `SHARED` in a loop; with plain
updates from concurrent callers, lost decrements or increments either leak it
or free it while the glob still holds it, and the same-size strings `churn`
allocates next reuse its block. `SHARED` is built at run time because a folded
literal is immortal and never touches its count.
"""

def make_shared -> str {
    t: int = 0;
    for i in range(10) {
        t = t + i;
    }
    return "shared-" + str(t);
}

glob SHARED: str = make_shared();

def hammer(n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        l: list[str] = [SHARED, SHARED];
        acc = acc + len(l[0]) + len(l[1]);
    }
    return acc;
}

def churn(n: int) -> int {
    junk: list[str] = [];
    for i in range(n) {
        junk.append("q" + str(100000 + i));
    }
    return len(junk);
}

def shared_intact -> int {
    return 1 if SHARED == "shared-45" else 0;
}
