"""Cross-module glob initializer test.

Imports cross_module_glob_init_lib and verifies that the imported module's
glob _TABLE list is properly initialized (not null / garbage) when first
accessed from this importing module.

Expected: table_len() returns 0 before any push, 1 and 2 after each push.
"""

import from cross_module_glob_init_lib { table_len, table_push, table_get }

def:pub run_glob_init_test() -> int {
    # Before any push the imported glob must be an empty (non-null) list.
    initial_len: int = table_len();
    table_push(42);
    after_one: int = table_len();
    table_push(99);
    after_two: int = table_len();
    # Encode three values into one i64: 0*10000 + 1*100 + 2 = 102
    return initial_len * 10000 + after_one * 100 + after_two;
}

def:pub get_first() -> int {
    return table_get(0);
}

def:pub get_second() -> int {
    return table_get(1);
}

# Empty entry block so that jac_entry() is emitted, which calls
# __jac_glob_init and __jac_glob_init_cross_module_glob_init_lib_na.
# Tests call jac_entry() first to initialize all module globs.
with entry {}
