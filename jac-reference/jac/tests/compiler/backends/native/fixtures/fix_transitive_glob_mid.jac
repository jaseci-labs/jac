"""Middle module for transitive-glob-init fix test.

Imports table_len and table_push from fix_transitive_glob_deep and
re-exports them.  The entry file only imports from this module directly;
fix_transitive_glob_deep is a transitive dep that must still have its
__jac_glob_init called.
"""

import from fix_transitive_glob_deep { table_len, table_push }

def:pub mid_len() -> int {
    return table_len();
}

def:pub mid_push(v: int) -> None {
    table_push(v);
}
