"""Builtins whose lowering needs a stack slot, called once per loop iteration.

A slot reserved where the call is would be a fresh one every iteration,
released only when the function returns, so a long enough loop runs off the
stack. Each function here repeats one such builtin `n` times."""

def floats(words: list[str], n: int) -> float {
    total = 0.0;
    for i in range(n) {
        total += float(words[i % len(words)]);
    }
    return total;
}

def ints(words: list[str], n: int) -> int {
    total = 0;
    for i in range(n) {
        total += int(words[i % len(words)]);
    }
    return total;
}

def tails(paths: list[str], n: int) -> int {
    total = 0;
    for i in range(n) {
        parts = paths[i % len(paths)].rpartition("/");
        total += len(parts[2]);
    }
    return total;
}

def set_checks(a: set[int], b: set[int], n: int) -> int {
    total = 0;
    for _ in range(n) {
        if a.issubset(b) {
            total += 1;
        }
        if b.isdisjoint(a.difference(b)) {
            total += 1;
        }
        total += len(a.union(b));
    }
    return total;
}

def fanned(xs: list[int], n: int) -> int {
    total = 0;
    for _ in range(n) {
        flow for v in &xs {
            total += v;
        }
    }
    return total;
}

glob ROUNDS: int = 200000,
     FAN_ROUNDS: int = 30000;

with entry {
    print(floats(["1.5", "2.25"], ROUNDS));
    print(ints(["3", "4"], ROUNDS));
    print(tails(["a/bc", "d/e/fgh"], ROUNDS));
    print(set_checks({1, 2}, {1, 2, 3}, ROUNDS));
    print(fanned([1, 2], FAN_ROUNDS));
}
