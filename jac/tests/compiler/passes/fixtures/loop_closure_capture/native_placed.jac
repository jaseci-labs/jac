"""Fixture: the loop-capture shapes the native backend lowers.

Analysis runs once for every codespace, so the same two captures are
reported (E2097) when this module is placed native: nativeLocal,
nativeStep.
"""

def body_local -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        nativeLocal = x * 10;
        out.append(lambda -> int { return nativeLocal; });
    }
    return out;
}

def counter -> list[Callable[[], int]] {
    out: list[Callable[[], int]] = [];
    for nativeStep = 0 while nativeStep < 3 with nativeStep += 1 {
        out.append(lambda -> int { return nativeStep; });
    }
    return out;
}

with entry {
    total = 0;
    for f in body_local() {
        total += f();
    }
    for g in counter() {
        total += g();
    }
    print(total);
}
