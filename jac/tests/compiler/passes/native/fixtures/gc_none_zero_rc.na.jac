"""Probe: --gc none must emit zero RC call sites.

Exercises the acyclic typed-release fast path (scope-exit release of an
acyclic obj), which historically bypassed the `none` gate that
`_emit_rc_retain` / `_emit_rc_release_simple` already had.
"""

obj Point {
    has x: float = 1.0,
        y: float = 2.0;
}

def use_point -> float {
    p = Point(x=3.0, y=4.0);
    return p.x + p.y;
}

glob total = 0.0;

with entry {
    for i in range(10) {
        total += use_point();
    }
    print(total);
}
