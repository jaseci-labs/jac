"""Importing module for the jac2c module-constant emit test.

Imports the module-level constant `LIMIT` (and free function `scale`) from
`const_lib` and references `LIMIT` across the module boundary. jac2c must
`extern` the imported constant so the reference resolves and links, while
emitting this module's own constant `LOCAL_MAX` as a file-scope definition.
"""

import from const_lib { LIMIT, scale }

glob LOCAL_MAX: int = 7;

def run_local -> int {
    return LOCAL_MAX;
}

def run_import -> int {
    return LIMIT;
}

def run_call -> int {
    return scale(LIMIT);
}
