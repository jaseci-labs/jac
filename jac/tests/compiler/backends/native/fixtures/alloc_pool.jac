"""Small objects recycled through the size-class pool, then threads.

Objects of several sizes, strings and small containers are made and dropped
in turn, so most allocations reuse a block an earlier free put in the pool;
a long-lived structure holds some of them across the churn. Then `flow`
starts threads, after which allocation and free go back to malloc: blocks
still in the pool, and objects allocated before the threads, are freed by
other threads from then on.
"""

obj Small {
    has v: int = 0;
}

obj Mid {
    has a: float = 0.0,
        b: float = 0.0,
        c: int = 0,
        tag: str = "";
}

obj Big {
    has a: int = 0,
        b: int = 0,
        c: int = 0,
        d: int = 0,
        e: int = 0,
        f: int = 0,
        g: int = 0;
}

def churn(n: int, keep: list[Mid]) -> int {
    total = 0;
    for i in range(n) {
        s = Small(v=i);
        m = Mid(a=1.0 * i, b=2.0, c=i % 7, tag=f"t{i % 13}");
        g = Big(a=i, g=i * 2);
        pair = (s.v, g.g);
        if i % 97 == 0 {
            keep.append(m);
        }
        total += s.v + m.c + g.g + pair[0] + len(m.tag);
    }
    return total;
}

def work(seed: int) -> int {
    keep: list[Mid] = [];
    total = churn(20000 + seed, keep);
    for m in keep {
        total += m.c;
    }
    return total;
}

with entry {
    keep: list[Mid] = [];
    first = churn(50000, keep);
    print(first, len(keep), keep[3].tag);
    h1 = flow work(1) ;
    h2 = flow work(2) ;
    a = wait h1 ;
    b = wait h2 ;
    print(a, b, churn(1000, keep), len(keep));
}
