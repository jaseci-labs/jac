"""Middle module for transitive-import fix test (FIX 1).

Imports get_leaf from fix_transitive_leaf and re-exports get_mid.
fix_transitive_entry only imports this module directly; the linker must
follow the transitive dependency to fix_transitive_leaf to satisfy
get_leaf at link time.
"""

import from fix_transitive_leaf { get_leaf }

def:pub get_mid() -> int {
    return get_leaf();
}
