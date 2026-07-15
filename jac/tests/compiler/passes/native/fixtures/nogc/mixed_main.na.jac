"""Enforced half of the mixed-binary fixture: zero-RC module calling a
managed module across the membrane with scalars only."""

import from mixed_lib { crunch }

obj Acc {
    has total: int = 0;
}

def gather(limit: int) -> int {
    a: own Acc = Acc();
    for i in range(limit) {
        a.total += crunch(i);
    }
    return a.total;
}

with entry {
    print(gather(5));
}
