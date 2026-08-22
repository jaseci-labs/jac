"""Imported library module for the jac2c module-constant emit test.

Defines a module-level constant `LIMIT` and a free function `scale`. Compiled
on its own it is a self-contained C translation unit that gives `LIMIT`
external linkage; the sibling `const_main.jac` imports the constant across the
module boundary and must `extern` it rather than emit an undefined symbol.
"""

glob LIMIT: int = 100;

def scale(x: int) -> int {
    return (x * 2);
}
