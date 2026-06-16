"""Issue #6687 fixture (imported half): a library module whose FFI lives behind
a dotted logical native import. The dotted form maps to an `$ORIGIN`-relative
path (`$ORIGIN/libs/libclibjit6687.so`) -- the AOT binary's loader honors that
token, but under `jac run` (in-process MCJIT) it must be stripped and resolved
relative to the cwd. Because this clib is pulled in TRANSITIVELY (the entry
module imports `compute`, not the library directly), it is loaded through the
imported-dependency clib path, which did not strip the token -- so the library
was never loaded into the JIT and `jac6687_triple` resolved to NULL, SIGSEGV."""

import from libs.clibjit6687 {
    def jac6687_triple(x: i64) -> i64;
}

def compute(x: i64) -> i64 {
    return jac6687_triple(x);
}
