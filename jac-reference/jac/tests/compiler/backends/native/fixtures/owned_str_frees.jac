"""Owned strings in an enforced module live on the owned heap and drop
at their extent: reassignment frees the old value, loop iterations free
per-iteration bindings, scope exit frees the last, moves and returns
transfer instead of freeing, and views never free. The leaks gate pins
teardown exact; RSS stays flat over the rebuild loop."""

def burn(n: int, seed: &str) -> int {
    t = 0;
    for i in range(n) {
        w: own str = seed + str(i);
        if w > seed {
            t = t + len(w);
        }
    }
    return t;
}

def relay(k: int) -> str {
    a: own str = "base-" + str(k);
    b: own str = a + "-more";
    return b;
}

def viewer(s: &str) -> int {
    piece = s[2:9];
    return len(piece);
}

glob n = 20000,
     seed: own str = "abcdefghijklmnopqrstuvwxy" + "z";

with entry {
    total = burn(n, &seed);
    moved = relay(7);
    total = total + len(moved) + viewer(&seed);
}

glob lit: own str = "static-literal";

with entry {
    total = total + len(lit);
    acc: own str = "";
    for j in range(50) {
        acc = acc + "x";
    }
    total = total + len(acc);
    print(total);
}
