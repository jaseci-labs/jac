"""A *args def must be rejected loudly on na (issue #7320 Cluster 3).

Before the fix it compiled and SIGTRAPped at runtime.
"""

def total(*nums: int) -> int {
    acc = 0;
    for n in nums {
        acc += n;
    }
    return acc;
}

def:pub call_total -> int {
    return total(1, 2, 3);
}

with entry {
    call_total();
}
