"""Native module that exports module-level globals.

Used by na_glob_import.na.jac to test cross-module global variable linkage.
Regression fixture for: global-internal-linkage-breaks-cross-module.
The fix changed global linkage from `internal` to `""` (default/public) in
globals.impl.jac so that importing modules can resolve the symbol at link time.
"""

glob MAGIC: int = 42;
glob BASE:  int = 100;

"""Return the value of the MAGIC global."""
def:pub get_magic() -> int {
    return MAGIC;
}

"""Return BASE + n."""
def:pub add_base(n: int) -> int {
    return BASE + n;
}
