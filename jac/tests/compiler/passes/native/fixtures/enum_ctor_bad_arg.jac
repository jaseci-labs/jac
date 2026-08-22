"""Fixture: an enum constructor handed a value that is not already an integer.

CPython raises `ValueError` for `Level(2.5)`, because no member carries that
value. Coercing the float to reach the member table would answer for `2`, a
value the caller never passed, so the emitter refuses the call by name and
leaves it to the Python fallback.
"""

enum Level { LOW = 2, MID = 25, HIGH = 40 }


def widen(v: float) -> int {
    return int(Level(v));
}
