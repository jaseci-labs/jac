"""Entry module for transitive-import fix test (FIX 1).

Imports get_mid from fix_transitive_mid (which transitively imports
fix_transitive_leaf).  Tests call get_mid() via ctypes and expect 99.
"""

import from fix_transitive_mid { get_mid }

def:pub run_transitive_test() -> int {
    return get_mid();
}

with entry {}
