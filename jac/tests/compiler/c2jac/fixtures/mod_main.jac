"""Importing module for the jac2c multi-module emit test.

Imports a ref-type `Counter` and a free function `add` from `mod_lib` and uses
them across the module boundary. jac2c must lower `Counter(...)` / `c.bump()` /
`c.get()` / `add(...)` to the same mangled `Counter__new` / `Counter__bump` /
`Counter__get` / `add` symbols the defining module emits, wiring them up with a
forward struct and `extern` prototypes while staying a separate C translation
unit.
"""

import from mod_lib { Counter, add }

def run_cross -> int {
    c = Counter(10);
    a = c.bump();
    b = c.bump();
    return add(a, b);
}

def run_get -> int {
    c = Counter(41);
    return c.get();
}
