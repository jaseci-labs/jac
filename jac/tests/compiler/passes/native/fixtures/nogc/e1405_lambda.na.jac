"""Must-fail under --enforce-nogc: escaping closure capture of a heap value (E1405)."""

glob data = [1, 2, 3],
     f = lambda (x: int) -> int { return x + len(data); };

with entry {
    print(f(1));
}
