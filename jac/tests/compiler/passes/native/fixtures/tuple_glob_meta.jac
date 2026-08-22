"""A module-level constant tuple declared with the widened `tuple`.

Natively referenced, so the unused-glob escape hatch does not apply: the
glob itself has to lower.
"""

glob MOVE_EXEMPT: tuple = ('len', 'id', );


def is_exempt(name: str) -> bool {
    return name in MOVE_EXEMPT;
}


def run -> int {
    return 1 if is_exempt('len') else 0;
}
