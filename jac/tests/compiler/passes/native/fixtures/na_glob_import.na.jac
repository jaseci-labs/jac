"""Native module that imports and directly reads globals from another module.

Used by TestCrossModuleGlobalLinkage in test_native_gen_pass.jac.
Regression fixture for: global-internal-linkage-breaks-cross-module.

Before the fix, globals in na_glob_export.na.jac were emitted with LLVM
`internal` linkage.  When this module declared the same names as `external`,
the linker renamed the original symbol (e.g. `@MAGIC -> @MAGIC.467`) and left
the external reference permanently null.  Any read therefore segfaulted.
After the fix, globals use default (public) linkage and the symbol resolves
correctly at JIT link time.
"""

import from na_glob_export { MAGIC, BASE, get_magic, add_base }

"""Read MAGIC directly — exercises the cross-module global access path."""
def:pub read_magic() -> int {
    return MAGIC;
}

"""Read MAGIC via a function call (sanity-check; not directly affected by the linkage bug)."""
def:pub read_magic_via_func() -> int {
    return get_magic();
}

"""Return MAGIC + BASE — reads both exported globals."""
def:pub sum_globals() -> int {
    return MAGIC + BASE;
}

"""Delegate to add_base — passes an int through an imported function."""
def:pub read_base_plus(n: int) -> int {
    return add_base(n);
}
