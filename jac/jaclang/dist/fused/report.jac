"""Launcher-side diagnostics: the two ways the fused runtime talks to the
user before CPython exists -- a narrated cold-start step, and a clean failure
exit. Kept apart from the I/O modules so every layer can import it."""

import from c { def write(fd: i32, data: bytes, length: int) -> int;  }
import from .platform { terminate }

"""Print a launcher failure and exit 70 (EX_SOFTWARE)."""
def:pub die(msg: str) {
    data = f"jac (launcher): {msg}\n".encode();
    write(i32(2), data, len(data));
    terminate(70);
}

"""Narrate a cold-start step to stderr (a silent multi-second stall reads as
a hang)."""
def:pub say(msg: str) {
    data = f"jac: {msg}\n".encode();
    write(i32(2), data, len(data));
}
