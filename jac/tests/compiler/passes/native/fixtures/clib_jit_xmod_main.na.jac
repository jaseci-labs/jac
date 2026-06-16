"""Issue #6687 fixture (entry half): runs under `jac run` (in-process MCJIT).
The entry calls into an imported module whose FFI is backed by a transitively
declared `$ORIGIN`-relative C shared library. Before the fix the JIT never
loaded that library, so the FFI call jumped to NULL and the process SIGSEGV'd;
the byte-identical program built with `jac nacompile` ran fine. Prints `21`."""

import from clib_jit_xmod_lib { compute }

with entry {
    print(compute(7));
}
