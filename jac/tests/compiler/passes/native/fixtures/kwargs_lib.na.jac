"""Companion library for kwargs_call.na.jac (issue #7026).

Exports a function with default-valued parameters so the importer can exercise
keyword-argument binding across a .na.jac module boundary.
"""

def:pub lib_greet(name: str = "z", n: int = 1) -> int {
    return len(name) * 100 + n;
}
