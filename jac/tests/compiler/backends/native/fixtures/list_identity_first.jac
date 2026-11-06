"""List searches test identity before `==`, as CPython's do: an element that
is the probe matches without calling its `__eq__`, and only the elements
before it are asked."""
glob asked: list[int] = [];

obj Shy {
    has k: int = 0;

    def __eq__(other: object) -> bool {
        asked.append(self.k);
        return False;
    }
}

with entry {
    xs = [Shy(k=1), Shy(k=2), Shy(k=3)];
    probe = xs[1];
    print(probe in xs, xs.index(probe), xs.count(probe));
    xs.remove(probe);
    print(len(xs), [x.k for x in xs]);
    print(asked);
}
