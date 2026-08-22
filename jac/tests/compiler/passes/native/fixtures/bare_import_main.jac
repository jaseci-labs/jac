"""Bare `import x` of a sibling plain .jac module on the native pathway.

Module-qualified calls (bare_import_helper.fn()) and glob attribute reads
(bare_import_helper.COUNT) must resolve at compile time to the linked
symbols of the dep - no runtime module object exists.
"""

import bare_import_helper;

def:pub use_fn -> int {
    return bare_import_helper.fn() + 1;
}

def:pub use_twice(n: int) -> int {
    return bare_import_helper.twice(n);
}

def:pub read_glob -> int {
    return bare_import_helper.COUNT;
}

# Empty entry block so jac_entry() is emitted; tests call it first to run
# __jac_glob_init for this module and the imported dep.
with entry {}
