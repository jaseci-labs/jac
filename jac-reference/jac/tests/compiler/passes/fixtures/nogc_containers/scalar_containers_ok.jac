"""Must stay clean: scalar list/dict/set with append/add/index/overwrite."""
def run -> int {
    xs = [1, 2, 3];
    xs.append(4);
    xs[0] = 9;
    d = {1: 10};
    d[2] = 20;
    s = {1, 2};
    s.add(3);
    return len(xs) + len(d) + len(s);
}

with entry {
    print(run());
}
