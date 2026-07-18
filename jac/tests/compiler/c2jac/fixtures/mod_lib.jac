"""Imported library module for the jac2c multi-module emit test.

Defines a reference-type `Counter` (heap object behind the RC header) and a
free function `add`. Compiled on its own it is a self-contained C translation
unit; the sibling `mod_main.jac` imports both symbols across the module
boundary.
"""

obj Counter {
    has n: int;

    def init(start: int) {
        self.n = start;
    }

    def bump -> int {
        self.n = self.n + 1;
        return self.n;
    }

    def get -> int {
        return self.n;
    }
}

def add(x: int, y: int) -> int {
    return (x + y);
}
