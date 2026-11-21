def scan(hay: own str, pat: own str) -> int {
    i = hay.find(pat);
    j = hay.find(pat, i + 1);
    ok = hay.startswith(pat);
    piece = hay[0:2];
    k = len(piece) + len(hay);
    if ok {
        return i + j + k;
    }
    return i + j;
}

with entry {
    print(scan("aabb", "ab"));
}
