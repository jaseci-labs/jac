"""random module cross-backend equivalence fixture (issue #6404, v1,
congruence decision #1: MT19937 seed→sequence parity).

Both backends seed(42) and draw the SAME ordered sequence; the native MT19937
must reproduce CPython's stream bit-for-bit (ints exact, floats within ULP).
ES/JS opts out.
"""

import random;

def random_py() -> dict {
    random.seed(42);
    r1: float = random.random();
    r2: float = random.random();
    r3: float = random.random();
    g32: int = random.getrandbits(32);
    g16: int = random.getrandbits(16);
    g40: int = random.getrandbits(40);
    ri1: int = random.randint(1, 100);
    ri2: int = random.randint(1, 100);
    ri3: int = random.randint(-50, 50);
    rr: int = random.randrange(1000);
    u: float = random.uniform(0.0, 1.0);
    random.seed(12345);
    s2: float = random.random();
    return {
        "r1": r1, "r2": r2, "r3": r3,
        "g32": g32, "g16": g16, "g40": g40,
        "ri1": ri1, "ri2": ri2, "ri3": ri3,
        "rr": rr, "u": u, "s2": s2,
    };
}

cl def random_cl() -> dict {
    return {};
}

na {
    def random_na() -> dict[str, any] {
        random.seed(42);
        r1: float = random.random();
        r2: float = random.random();
        r3: float = random.random();
        g32: int = random.getrandbits(32);
        g16: int = random.getrandbits(16);
        g40: int = random.getrandbits(40);
        ri1: int = random.randint(1, 100);
        ri2: int = random.randint(1, 100);
        ri3: int = random.randint(-50, 50);
        rr: int = random.randrange(1000);
        u: float = random.uniform(0.0, 1.0);
        random.seed(12345);
        s2: float = random.random();
        return {
            "r1": r1, "r2": r2, "r3": r3,
            "g32": g32, "g16": g16, "g40": g40,
            "ri1": ri1, "ri2": ri2, "ri3": ri3,
            "rr": rr, "u": u, "s2": s2,
        };
    }
}
