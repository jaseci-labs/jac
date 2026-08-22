"""Entry module for transitive-glob-init fix test.

Directly imports only fix_transitive_glob_mid.  fix_transitive_glob_deep is
a transitive dep: mid imports it, na_compile_pass links it, and after the
fix _codegen_entry also emits __jac_glob_init_<safe_name>() for it so its
glob list is properly initialised before any call through mid.

Expected: mid_len() returns 0 initially; after mid_push(42) returns 1.
"""

import from fix_transitive_glob_mid { mid_len, mid_push }

def:pub run_transitive_glob_len() -> int {
    return mid_len();
}

def:pub run_transitive_glob_push_and_len() -> int {
    mid_push(42);
    return mid_len();
}

with entry {}
