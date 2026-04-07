"""Library module for transitive-clib-loading fix test.

Imports sqrt from libm — the important part is that _clib_paths is recorded
on this module's IR.  fix_clib_transitive_entry imports *this* module and
must therefore inherit the libm dependency so MCJIT can resolve sqrt at
JIT-link time.  Before the fix the .so was never re-loaded when the entry
module was compiled, causing an unresolved-symbol segfault.
"""

import from "/usr/lib/x86_64-linux-gnu/libm.so.6" {
    def sqrt(x: f64) -> f64;
}

def:pub wrapped_sqrt(x: f64) -> f64 {
    return sqrt(x);
}

with entry {}
