"""Bare from-imported stdlib names cross-backend equivalence fixture.

`import from random { randint }` binds the same function `random.randint`
names, so a bare `randint(1, 6)` must lower natively exactly like the
qualified call instead of demoting its caller. Covers the intercepted
modules (random, struct, os), an aliased name, and a local that shadows an
imported name. ES/JS opts out.
"""

import from random { seed, random, randint as roll, getrandbits }
import from struct { pack, unpack, calcsize }
import from os { getpid, getcwd }

def _shadowed_py -> float {
    random = lambda -> float { return 0.5; };
    return random();
}

def from_imports_py -> dict[str, any] {
    seed(42);
    r: float = random();
    d: int = roll(1, 100);
    g: int = getrandbits(16);
    packed: bytes = pack("<ih", 7, -2);
    (a, b) = unpack("<ih", packed);
    size: int = calcsize("<ih");
    pid_ok: bool = getpid() > 0;
    cwd_ok: bool = len(getcwd()) > 0;
    shadowed: float = _shadowed_py();
    return {
        "r": r,
        "d": d,
        "g": g,
        "a": a,
        "b": b,
        "size": size,
        "packed_len": len(packed),
        "pid_ok": pid_ok,
        "cwd_ok": cwd_ok,
        "shadowed": shadowed
    };
}

def from_imports_cl -> dict[str, any] {
    return {};
}

def _shadowed_na -> float {
    random = lambda -> float { return 0.5; };
    return random();
}

def from_imports_na -> dict[str, any] {
    seed(42);
    r: float = random();
    d: int = roll(1, 100);
    g: int = getrandbits(16);
    packed: bytes = pack("<ih", 7, -2);
    (a, b) = unpack("<ih", packed);
    size: int = calcsize("<ih");
    pid_ok: bool = getpid() > 0;
    cwd_ok: bool = len(getcwd()) > 0;
    shadowed: float = _shadowed_na();
    return {
        "r": r,
        "d": d,
        "g": g,
        "a": a,
        "b": b,
        "size": size,
        "packed_len": len(packed),
        "pid_ok": pid_ok,
        "cwd_ok": cwd_ok,
        "shadowed": shadowed
    };
}
