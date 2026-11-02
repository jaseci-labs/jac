"""Static methods called through a module alias: `alias.Class.method()`."""

import qualified_static_lib as lib;
import from qualified_static_lib { Scale }

def total(n: int) -> int {
    return lib.Scale.doubled(n) + lib.Scale.offset(n, 3);
}

with entry {
    print(lib.Scale.doubled(4));
    print(total(5));
    print(Scale.doubled(6));
}
