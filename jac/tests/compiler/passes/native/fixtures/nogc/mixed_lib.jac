"""Managed half of the mixed-binary fixture: ordinary RC/managed code."""

def crunch(n: int) -> int {
    acc = [];
    for i in range(n) {
        acc.append(i * i);
    }
    total = 0;
    for v in acc {
        total += v;
    }
    return total;
}
