"""Base module structure: Module and element docstrings, entry points.

This is the module-level docstring.
It describes the purpose of the entire module.
"""

def add(a: int, b: int) -> int {
    return a + b;
}

def subtract(a: int, b: int) -> int {
    return a - b;
}

# Default entry point
with entry {
    print("Default entry:", add(5, subtract(8, 3)));
}

# Named entry point
with entry:__main__ {
    print("Named entry:", add(1, subtract(3, 1)));
}
