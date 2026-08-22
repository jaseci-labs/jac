"""Launcher-side diagnostics: the two ways the fused runtime talks to the
user before CPython exists -- a narrated cold-start step, and a clean failure
exit. Kept apart from the I/O modules so every layer can import it."""

import sys;

"""Print a launcher failure and exit 70 (EX_SOFTWARE)."""
def:pub die(msg: str) {
    print(f"jac (launcher): {msg}", file=sys.stderr);
    sys.`exit(70);
}

"""Narrate a cold-start step to stderr (a silent multi-second stall reads as
a hang)."""
def:pub say(msg: str) {
    print(f"jac: {msg}", file=sys.stderr);
}
