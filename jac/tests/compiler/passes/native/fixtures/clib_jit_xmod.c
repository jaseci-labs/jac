/* Issue #6687 fixture: a tiny C shared library the test compiles at runtime.
   Imported (via a dotted logical native import that carries an $ORIGIN loader
   token) by clib_jit_xmod_lib.na.jac, which is in turn imported by
   clib_jit_xmod_main.na.jac. */
long jac6687_triple(long x) { return x * 3; }
