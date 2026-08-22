"""Entry of a cyclic module pair with runtime glob initializers.

Pins the glob-init once-guard for import cycles (issue #7593 item 11):
compiling and running must not crash, and each module's initializer runs
exactly once, leaving own-module globs with their initialized values.
"""

import from cycle_glob_b { get_bv }

def:pub mk_av() -> int {
    return 5 + 6;
}

glob av: int = mk_av();

def:pub get_av() -> int {
    return av;
}

def:pub read_bv() -> int {
    return get_bv();
}

with entry {}
