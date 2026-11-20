"""Slice-heavy string surface: substrings taken in a loop and consumed
by length, truthiness, and pass-through -- the zero-copy view gate.
Output must stay byte-identical across gc modes: root-retained views
under managed modes, rootless derivation-bounded views under the
enforced headerless build."""

def probe(s: &str, n: int) -> int {
    t = 0;
    for i in range(n) {
        a = i % 5;
        b = a + 1 + (i % 7);
        piece = s[a:b];
        t = (t + len(piece) * (i + 1)) % 1000000007;
        if piece {
            t = (t + 1) % 1000000007;
        }
    }
    return t;
}

def mk -> str {
    base: own str = "abcdefghijkl";
    return base + "mnopqrstuvwx";
}

with entry {
    w: own str = mk();
    print(probe(&w, 5000));
    print("end");
}
