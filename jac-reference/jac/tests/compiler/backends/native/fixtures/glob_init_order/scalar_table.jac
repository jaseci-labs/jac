"""Globals a function computes, in a module that imports back from its reader."""

import from scalar_holder { slot_bytes }

def measure(count: int) -> int {
    return count * slot_bytes();
}

glob COUNT: int = measure(1) - 5,
     WIDTH: int = measure(COUNT);

def describe -> str {
    return f"{COUNT}x{WIDTH}";
}
