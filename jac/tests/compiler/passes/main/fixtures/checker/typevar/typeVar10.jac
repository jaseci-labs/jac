"""Tests handling of constrained TypeVars with ellipsis stub bodies.

From Pyright sample: typeVar10.py

Ellipsis-only function bodies are stubs and should NOT trigger E1004
("may implicitly return None"). This matches Pyright's behavior.

Expected: 0 errors — stub methods with `...;` should be accepted.
"""

import from typing { TypeVar }

class A {
    def method(self: A, x: "A") -> "A" {
        ...;
    }
}

class B {
    def method(self: B, x: "B") -> "B" {
        ...;
    }
}

with entry {
    T = TypeVar("T", A, B);
}

def check(x: T, y: T) -> T {
    return x.method(y);
}
