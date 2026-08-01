"""Entry module for transitive-clib-loading fix test.

Only imports fix_clib_transitive_lib (not libm directly).  The compile pass
must propagate fix_clib_transitive_lib's _clib_paths to this module and
re-load libm before JIT-linking so sqrt resolves correctly.
"""

import from fix_clib_transitive_lib { wrapped_sqrt }

def:pub test_transitive_clib_sqrt() -> f64 {
    # sqrt(9.0) == 3.0 -- only works if libm was loaded transitively
    return wrapped_sqrt(9.0);
}

with entry {}
